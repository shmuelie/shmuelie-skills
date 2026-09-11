using System.Net;
using System.Text;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Http.HttpClientLibrary;
using OpenApiClientFixture.Generated;

await VerifyBaseUrlOwnershipAsync();
Console.WriteLine($"Runtime: {Environment.Version}");
Console.WriteLine("PASS: generated endpoint ownership and fake transport");

static async Task VerifyBaseUrlOwnershipAsync()
{
    var handler = new RecordingHandler();
    using var httpClient = new HttpClient(handler);
    using var configuredAdapter = new HttpClientRequestAdapter(
        new AnonymousAuthenticationProvider(),
        httpClient: httpClient)
    {
        BaseUrl = "https://configured.example.test/v3"
    };

    var configuredClient = new WidgetApiClient(configuredAdapter);
    AssertEqual(
        "https://configured.example.test/v3",
        configuredAdapter.BaseUrl,
        "The generated constructor should preserve a preconfigured adapter URL.");

    var firstWidget = await configuredClient.Widgets["widget-1"].GetAsync();
    AssertEqual("widget-1", firstWidget?.Id, "The generated JSON model should deserialize.");
    AssertEqual(
        "https://configured.example.test/v3/widgets/widget-1",
        handler.RequestUris[0].AbsoluteUri,
        "Preconstruction application configuration should own the endpoint.");

    using var fallbackAdapter = new HttpClientRequestAdapter(
        new AnonymousAuthenticationProvider(),
        httpClient: httpClient);
    var fallbackClient = new WidgetApiClient(fallbackAdapter);
    AssertEqual(
        "https://spec.example.test/v1",
        fallbackAdapter.BaseUrl,
        "An empty adapter should receive the enriched spec server URL.");

    fallbackAdapter.BaseUrl = "https://later-assignment.example.test/v4";
    AssertEqual(
        "https://later-assignment.example.test/v4",
        fallbackAdapter.BaseUrl,
        "A later sequential assignment should overwrite the adapter property.");

    var secondWidget = await fallbackClient.Widgets["widget-2"].GetAsync();
    AssertEqual("widget-2", secondWidget?.Id, "The second fake response should deserialize.");
    AssertEqual(
        "https://later-assignment.example.test/v4/widgets/widget-2",
        handler.RequestUris[1].AbsoluteUri,
        "The later adapter assignment should control the resolved request URI.");
    AssertEqual(2, handler.RequestUris.Count, "The fixture should issue two fake requests.");
}

static void AssertEqual<T>(T expected, T actual, string message)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException(
            $"{message} Expected '{expected}', actual '{actual}'.");
    }
}

sealed class RecordingHandler : HttpMessageHandler
{
    public List<Uri> RequestUris { get; } = [];

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        RequestUris.Add(request.RequestUri ??
            throw new InvalidOperationException("The generated request URI was null."));
        var id = RequestUris.Count == 1 ? "widget-1" : "widget-2";

        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        {
            RequestMessage = request,
            Content = new StringContent(
                $$"""{"id":"{{id}}","name":"synthetic"}""",
                Encoding.UTF8,
                "application/json")
        });
    }
}
