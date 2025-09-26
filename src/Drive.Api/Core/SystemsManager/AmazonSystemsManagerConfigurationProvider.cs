using Amazon;
using Amazon.SimpleSystemsManagement;
using Amazon.SimpleSystemsManagement.Model;

namespace Drive.Api.Core.SystemsManager;

public class AmazonSystemsManagerConfigurationProvider(string region, string path) : ConfigurationProvider
{
    public override void Load()
    {
        Data = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);

        using var client = new AmazonSimpleSystemsManagementClient(RegionEndpoint.GetBySystemName(region));

        string? nextToken = null;
        do
        {
            var request = new GetParametersByPathRequest
            {
                Path = path,
                Recursive = true,
                WithDecryption = true,
                NextToken = nextToken
            };

            var response = client.GetParametersByPathAsync(request).Result;

            foreach (var p in response.Parameters)
            {
                var key = ToConfigKey(path, p.Name);
                Data[key] = p.Value;
            }

            nextToken = response.NextToken;
        } while (!string.IsNullOrEmpty(nextToken));
    }

    private static string ToConfigKey(string rootPath, string fullName)
    {
        var prefix = rootPath.TrimEnd('/');
        var name = fullName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            ? fullName[prefix.Length..]
            : fullName;

        return name.TrimStart('/').Replace('/', ':');
    }
}

