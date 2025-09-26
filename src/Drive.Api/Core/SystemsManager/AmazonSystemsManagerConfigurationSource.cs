namespace Drive.Api.Core.SystemsManager;

public class AmazonSystemsManagerConfigurationSource(string region, string path) : IConfigurationSource
{
    public IConfigurationProvider Build(IConfigurationBuilder builder) =>
        new AmazonSystemsManagerConfigurationProvider(region, path);
}

