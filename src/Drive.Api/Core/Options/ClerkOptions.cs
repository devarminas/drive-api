using System.ComponentModel.DataAnnotations;

namespace Drive.Api.Core.Options;

public class ClerkOptions
{
    [Required]
    public string Authority { get; set; } = default!;

    [Required]
    public string AuthorizedParty { get; set; } = default!;
}

