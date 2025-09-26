using Amazon.S3;
using Amazon.S3.Model;
using Drive.Api.Domain;
using Drive.Api.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.StaticFiles;
using Wolverine.Http;

namespace Drive.Api;

public sealed record AlbumUploadRequest(string FileName);

public sealed record AlbumUploadResponse(string UploadUrl, string Key, string Location) : CreationResponse(Location);

public class AlbumUploadEndpoint
{
	private static readonly FileExtensionContentTypeProvider Provider = new();

	[WolverinePost("/api/albums/{id}/upload"), Authorize, Tags("Drive")]
    public static async Task<(AlbumUploadResponse, Upload, UploadTimeout)> AlbumUpload(
        AlbumUploadRequest request,
        Album album,
        UploadMetadata metadata,
        IAmazonS3 s3Service,
        IConfiguration configuration)
    {
        var validFor = TimeSpan.FromMinutes(30);
        var initiatedDate = DateTime.UtcNow;
        var expirationDate = initiatedDate.Add(validFor);
        var bucketName = configuration["S3_BUCKET_NAME"] ?? throw new InvalidOperationException("S3_BUCKET_NAME is not configured.");
        var cloudfrontDomain = configuration["CLOUDFRONT_DOMAIN"] ?? string.Empty;
        var presignedUrl = await s3Service.GetPreSignedURLAsync(new GetPreSignedUrlRequest
        {
            BucketName = bucketName,
            Key = metadata.S3Key,
            Verb = HttpVerb.PUT,
            Expires = expirationDate,
            ContentType = metadata.ContentType,
            Headers =
            {
                ["If-None-Match"] = "*"
            }
        });

        var cfBase = string.IsNullOrWhiteSpace(cloudfrontDomain)
            ? string.Empty
            : (cloudfrontDomain.StartsWith("http", StringComparison.OrdinalIgnoreCase)
                ? cloudfrontDomain.TrimEnd('/')
                : $"https://{cloudfrontDomain.TrimEnd('/')}");

        var location = string.IsNullOrWhiteSpace(cfBase)
            ? metadata.S3Key
            : $"{cfBase}/{metadata.S3Key}";

        return (
            new AlbumUploadResponse(presignedUrl, metadata.S3Key, location),
            new Upload(metadata.FileId, metadata.S3Key, request.FileName, metadata.ContentType, album.Id),
            new UploadTimeout(metadata.S3Key, validFor)
        );
    }

	public static (UploadMetadata? metadata, IResult result) Load(AlbumUploadRequest request)
	{
		var extension = Path.GetExtension(request.FileName);
		if (Provider.Mappings.TryGetValue(extension, out var contentType))
		{
			return (new UploadMetadata(extension, contentType), WolverineContinue.Result());
		}

		return (null, Results.BadRequest());
	}

	public static async Task<(Album? album, IResult result)> LoadAsync(string id, ApplicationDbContext context)
	{
		if (!Ulid.TryParse(id, out var albumId))
		{
			return (null, Results.NotFound());
		}

		var album = await context.Albums.FindAsync(albumId);
		return album is null
			? (album, Results.NotFound())
			: (album, WolverineContinue.Result());
	}
}

public record UploadMetadata(string Extension, string ContentType)
{
	public Ulid FileId { get; } = Ulid.NewUlid();

	public string S3Key => $"files/{FileId}{Extension}";
}
