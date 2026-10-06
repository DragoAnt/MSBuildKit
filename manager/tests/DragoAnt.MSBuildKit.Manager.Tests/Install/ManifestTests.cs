using DragoAnt.MSBuildKit.Manager.Install;
using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Install;

public sealed class ManifestTests
{
    private const string HashA = "0000000000000000000000000000000000000000000000000000000000000000";
    private const string HashB = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";

    // language=json
    private const string Canonical = """
        {
          "schema": 1,
          "packages": [
            {
              "id": "Contoso.MSBuildKit",
              "version": "1.0.0"
            },
            {
              "id": "DragoAnt.MSBuildKit.Core",
              "version": "0.3.0-beta.1"
            }
          ],
          "files": [
            {
              "path": "msbuild/DragoAnt.MSBuildKit.Core/init.props",
              "package": "DragoAnt.MSBuildKit.Core",
              "sha256": "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
            },
            {
              "path": "msbuild/init.company.props",
              "package": "Contoso.MSBuildKit",
              "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
            },
            {
              "path": "msbuild/init.props",
              "package": null,
              "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
            }
          ]
        }

        """;

    [Fact]
    public void RoundTrip_IsByteStable()
    {
        var text = Canonical.ReplaceLineEndings("\n");

        var once = Manifest.Parse(text).ToJson();

        once.Should().Be(text);
        Manifest.Parse(once).ToJson().Should().Be(once);
    }

    [Fact]
    public void ToJson_SortsPackagesAndFiles_AndWritesLfOnly()
    {
        var manifest = new Manifest(
            [new ManifestPackage("DragoAnt.MSBuildKit.Core", "0.3.0-beta.1"), new ManifestPackage("Contoso.MSBuildKit", "1.0.0")],
            [
                new ManifestFile("msbuild/init.props", null, HashA),
                new ManifestFile("msbuild/init.company.props", "Contoso.MSBuildKit", HashA),
                new ManifestFile("msbuild/DragoAnt.MSBuildKit.Core/init.props", "DragoAnt.MSBuildKit.Core", HashB),
            ]);

        var json = manifest.ToJson();

        json.Should().Be(Canonical.ReplaceLineEndings("\n"));
        json.Should().NotContain("\r");
    }

    [Fact]
    public void Parse_ReadsFilesAndPackages()
    {
        var manifest = Manifest.Parse(Canonical);

        manifest.Packages.Should().HaveCount(2);
        manifest.Files.Should().Contain(new ManifestFile("msbuild/init.props", null, HashA));
        manifest.Files.Should().Contain(new ManifestFile("msbuild/DragoAnt.MSBuildKit.Core/init.props", "DragoAnt.MSBuildKit.Core", HashB));
    }

    [Theory]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "../x", "package": null, "sha256": "0000000000000000000000000000000000000000000000000000000000000000" } ] }""", "../x")]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "msbuild\\x", "package": null, "sha256": "0000000000000000000000000000000000000000000000000000000000000000" } ] }""", "msbuild\\x")]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "/x", "package": null, "sha256": "0000000000000000000000000000000000000000000000000000000000000000" } ] }""", "/x")]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "x", "package": null, "sha256": "ABC" } ] }""", "ABC")]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "x", "package": "Missing.Package", "sha256": "0000000000000000000000000000000000000000000000000000000000000000" } ] }""", "Missing.Package")]
    [InlineData("""{ "schema": 1, "packages": [], "files": [ { "path": "a/X", "package": null, "sha256": "0000000000000000000000000000000000000000000000000000000000000000" }, { "path": "a/x", "package": null, "sha256": "0000000000000000000000000000000000000000000000000000000000000000" } ] }""", "a/x")]
    [InlineData("""{ "schema": 1, "packages": [ { "id": "A", "version": "1.0.0" }, { "id": "a", "version": "2.0.0" } ], "files": [] }""", "'a'")]
    [InlineData("""{ "schema": 2, "packages": [], "files": [] }""", "schema")]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => Manifest.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitLayout.ManifestFileName).And.Contain(mentioned);
    }
}
