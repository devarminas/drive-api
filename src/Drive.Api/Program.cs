using Amazon.S3;
using Amazon.SecretsManager;
using Drive.Api;
using Drive.Api.Core.Clerk;
using Drive.Api.Core.OpenApi;
using Drive.Api.Core.SecretManager;
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

var builder = WebApplication.CreateBuilder(args);

// Configuration
var awsRegion = Environment.GetEnvironmentVariable("AWS_REGION") ?? "eu-central-1";
var dbSecretArnOrName = Environment.GetEnvironmentVariable("DB_SECRET_ARN");
var appSecretsName = Environment.GetEnvironmentVariable("APP_SECRETS_NAME") ?? "drive-api";

if (!string.IsNullOrWhiteSpace(dbSecretArnOrName))
{
    builder.Configuration.AddAmazonSecretsManager(awsRegion, dbSecretArnOrName);
}

builder.Configuration.AddAmazonSecretsManager(awsRegion, appSecretsName);
var host = builder.Configuration["host"];
var username = builder.Configuration["username"];
var password = builder.Configuration["password"];
var connectionString = $"Host={host};Database=drive;Username={username};Password={password};SSL Mode=Require;Trust Server Certificate=true";

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
		options.Authority = "https://comic-kitten-33.clerk.accounts.dev";
		options.AuthorizedParty = "http://localhost:5173";
	});

builder.Services.AddAuthorizationBuilder();

// Host
builder.Host.UseWolverine(opts =>
{
	opts.UseEntityFrameworkCoreTransactions();
	opts.Policies.AutoApplyTransactions();
	opts.PersistMessagesWithPostgresql(connectionString, "wolverine");
	opts.UseAmazonSqsTransport().AutoProvision().AutoPurgeOnStartup();

	opts.ListenToSqsQueue("upload-completed")
		.ReceiveRawJsonMessage(typeof(S3UploadCompleted), o =>
		{
			o.Converters.Add(new S3EventToUploadCompletedConverter());
		});

	opts.PublishMessage<UploadTimeout>().ToSqsQueue("upload-timeout");
	opts.ListenToSqsQueue("upload-timeout");
	opts.PublishMessage<CreateFileCommand>().ToSqsQueue("create-file");
	opts.ListenToSqsQueue("create-file");
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
