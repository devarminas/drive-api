namespace Drive.Api.Core.SystemsManager;

public static class AmazonSystemsManagerExtensions
{
    public static void AddAmazonSystemsManager(this IConfigurationBuilder configurationBuilder, string region, string path)
    {
        var configurationSource = new AmazonSystemsManagerConfigurationSource(region, path);
        configurationBuilder.Add(configurationSource);
    }
}

