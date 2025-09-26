using Amazon.S3;
using Amazon.SecretsManager;
using Drive.Api;
using Drive.Api.Core.Clerk;
using Drive.Api.Core.OpenApi;
using Drive.Api.Core.SecretManager;
using Drive.Api.Core.SystemsManager;
using Drive.Api.Persistence;
using JasperFx.Resources;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;
using Wolverine;
using Wolverine.AmazonSqs;
using Wolverine.EntityFrameworkCore;
using Wolverine.Http;
using Wolverine.Http.FluentValidation;
using Wolverine.Postgresql;
using Drive.Api.Core.Options;

var builder = WebApplication.CreateBuilder(args);

// Configuration
var awsRegion = Environment.GetEnvironmentVariable("AWS_REGION") ?? "eu-central-1";

// In Development, load shared config from SSM Parameter Store
if (builder.Environment.IsDevelopment())
{
    builder.Configuration.AddAmazonSystemsManager(awsRegion, "/drive-api/dev");
}

// Prefer explicit env var, else look up secret name/arn from configuration (e.g., SSM)
var dbSecretArnOrName = Environment.GetEnvironmentVariable("DB_SECRET_ARN")
    ?? builder.Configuration["Db:SecretArn"]
    ?? builder.Configuration["Db:SecretName"];

if (!string.IsNullOrWhiteSpace(dbSecretArnOrName))
{
	builder.Configuration.AddAmazonSecretsManager(awsRegion, dbSecretArnOrName);
}

// Options validation (fail fast in Development)
var clerkOptionsBuilder = builder.Services.AddOptions<ClerkOptions>()
    .Bind(builder.Configuration.GetSection("Clerk"))
    .ValidateDataAnnotations();

if (builder.Environment.IsDevelopment())
{
    clerkOptionsBuilder
        .Validate(o => !string.IsNullOrWhiteSpace(o.Authority), "Clerk:Authority is required in Development")
        .Validate(o => !string.IsNullOrWhiteSpace(o.AuthorizedParty), "Clerk:AuthorizedParty is required in Development")
        .ValidateOnStart();
}

// Connection settings: prefer explicit env vars, then values from Secrets Manager, with sensible defaults
var host = Environment.GetEnvironmentVariable("DB_HOST") ?? builder.Configuration["host"] ?? string.Empty;
var port = Environment.GetEnvironmentVariable("DB_PORT") ?? builder.Configuration["port"] ?? "5432";
var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? builder.Configuration["dbname"] ?? "drive";
var username = Environment.GetEnvironmentVariable("DB_USERNAME") ?? builder.Configuration["username"];
var password = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? builder.Configuration["password"];

if (string.IsNullOrWhiteSpace(host))
{
	throw new InvalidOperationException("Database host is not configured. Provide DB_HOST env var or include 'host' in the secret.");
}

var connectionString = $"Host={
	host
};Port={
	port
};Database={
	dbName
};Username={
	username
};Password={
	password
};SSL Mode=Require;Trust Server Certificate=true";

builder.Services.AddOpenApi(opts =>
{
	opts.AddDocumentTransformer<TransformerSecurityScheme>();
});

builder.Services.AddHealthChecks();
builder.Services.AddWolverineHttp();

// Services
builder.Services.AddAWSService<IAmazonSecretsManager>();
builder.Services.AddAWSService<IAmazonS3>();
builder.Services.AddResourceSetupOnStartup();
builder.Services.AddDbContextWithWolverineIntegration<ApplicationDbContext>(x =>
{
	x.UseNpgsql(connectionString);
});

builder.Services.AddAuthentication(ClerkAuthenticationDefaults.AuthenticationScheme)
    .AddClerkAuthentication(ClerkAuthenticationDefaults.AuthenticationScheme, options =>
    {
        options.Authority = builder.Configuration["Clerk:Authority"] ?? "https://comic-kitten-33.clerk.accounts.dev";
        options.AuthorizedParty = builder.Configuration["Clerk:AuthorizedParty"] ?? "http://localhost:5173";
    });

builder.Services.AddAuthorizationBuilder();

// Host
builder.Host.UseWolverine(opts =>
{
	opts.UseEntityFrameworkCoreTransactions();
	opts.Policies.AutoApplyTransactions();
	opts.PersistMessagesWithPostgresql(connectionString, "wolverine");
	opts.UseAmazonSqsTransport();

    var uploadCompletedQueueName = builder.Configuration["Queues:UploadCompleted"]
                                   ?? Environment.GetEnvironmentVariable("UPLOAD_COMPLETED_QUEUE_NAME")
                                   ?? "upload-completed";
    var uploadTimeoutQueueName = builder.Configuration["Queues:UploadTimeout"]
                                  ?? Environment.GetEnvironmentVariable("UPLOAD_TIMEOUT_QUEUE_NAME")
                                  ?? "upload-timeout";
    var createFileQueueName = builder.Configuration["Queues:CreateFile"]
                               ?? Environment.GetEnvironmentVariable("CREATE_FILE_QUEUE_NAME")
                               ?? "create-file";

	opts.ListenToSqsQueue(uploadCompletedQueueName)
		.ReceiveRawJsonMessage(typeof(S3UploadCompleted), o =>
		{
			o.Converters.Add(new S3EventToUploadCompletedConverter());
		});

	opts.PublishMessage<UploadTimeout>().ToSqsQueue(uploadTimeoutQueueName);
	opts.ListenToSqsQueue(uploadTimeoutQueueName);
	opts.PublishMessage<CreateFileCommand>().ToSqsQueue(createFileQueueName);
	opts.ListenToSqsQueue(createFileQueueName);
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
	app.MapOpenApi();
	app.MapScalarApiReference(opts =>
	{
		opts.Theme = ScalarTheme.DeepSpace;
	});
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/healthz");
app.MapWolverineEndpoints(opts =>
{
	opts.UseFluentValidationProblemDetailMiddleware();
});

app.Run();
