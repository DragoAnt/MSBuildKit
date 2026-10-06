using DragoAnt.MSBuildKit.Manager.Install;
using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Install;

public sealed class KitJsonTests
{
    // language=json
    private const string Schema2 = """
        {
          "schema": 2,
          "filters": [
            {
              "package": "DragoAnt.MSBuildKit.Company",
              "source": "nuget.org"
            }
          ],
          "parts": {
            "enable": [
              "PackageAsProj"
            ],
            "disable": []
          },
          "prerelease": false,
          "source": "feed"
        }

        """;

    [Fact]
    public void Parse_Schema2_ReadsEveryField()
    {
        var kit = KitJson.Parse(Schema2);

        kit.ReadSchema.Should().Be(2);
        kit.Legacy.Should().BeNull();
        kit.Filters.Should().ContainSingle().Which.Should().Be(new KitJsonFilter("DragoAnt.MSBuildKit.Company", "nuget.org"));
        kit.Parts.Enable.Should().Equal("PackageAsProj");
        kit.Parts.Disable.Should().BeEmpty();
        kit.Prerelease.Should().BeFalse();
        kit.Source.Should().Be(KitSourceKind.Feed);
    }

    [Fact]
    public void ToJson_Schema2_IsByteStable()
    {
        var text = Schema2.ReplaceLineEndings("\n");

        KitJson.Parse(text).ToJson().Should().Be(text);
    }

    [Fact]
    public void Parse_Schema2_WithOnlyTheSchema_UsesDefaults()
    {
        var kit = KitJson.Parse("""{ "schema": 2 }""");

        kit.Filters.Should().BeEmpty();
        kit.Parts.Enable.Should().BeEmpty();
        kit.Parts.Disable.Should().BeEmpty();
        kit.Prerelease.Should().BeFalse();
        kit.Source.Should().Be(KitSourceKind.Feed);
    }

    [Fact]
    public void Parse_Schema2_AcceptsCommentsAndTrailingCommas()
    {
        var kit = KitJson.Parse("""
            {
              // hand-edited
              "schema": 2,
              "parts": { "enable": [ "EF", ], },
              "source": "local",
            }
            """);

        kit.Parts.Enable.Should().Equal("EF");
        kit.Source.Should().Be(KitSourceKind.Local);
    }

    [Fact]
    public void Parse_Schema1_SingleLineParts_BecomeEnabledParts()
    {
        var kit = KitJson.Parse("""
            {
              "repository": "DragoAnt/MSBuildKit",
              "version": "0.2.1",
              "sha256": "ab12",
              "parts": ["EF","PackageAsProj"]
            }
            """);

        kit.ReadSchema.Should().Be(1);
        kit.Legacy.Should().Be(new KitJsonLegacy("DragoAnt/MSBuildKit", "0.2.1", "ab12"));
        kit.Parts.Enable.Should().Equal("EF", "PackageAsProj");
        kit.Parts.Disable.Should().BeEmpty();
        kit.Filters.Should().BeEmpty();
    }

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    public void Parse_Schema1_MultiLinePartsArray_KeepsEveryPart(string newline)
    {
        var text = string.Join(newline,
            "{",
            "  \"repository\": \"DragoAnt/MSBuildKit\",",
            "  \"version\": \"0.2.1\",",
            "  \"sha256\": \"\",",
            "  \"parts\": [",
            "    \"Project.RoslynComponent\",",
            "    \"Project.CodeAnalyzer\",",
            "    \"EF\"",
            "  ]",
            "}",
            "");

        var kit = KitJson.Parse(text);

        kit.Parts.Enable.Should().Equal("Project.RoslynComponent", "Project.CodeAnalyzer", "EF");
    }

    [Fact]
    public void Parse_Schema1_EmptyParts_EnablesNothing()
    {
        var kit = KitJson.Parse("""{ "repository": "DragoAnt/MSBuildKit", "version": "0.0.1", "sha256": "", "parts": [] }""");

        kit.ReadSchema.Should().Be(1);
        kit.Parts.Enable.Should().BeEmpty();
    }

    [Fact]
    public void ToJson_AfterSchema1_WritesSchema2WithoutTheLegacyFields()
    {
        var json = KitJson.Parse("""{ "repository": "DragoAnt/MSBuildKit", "version": "0.2.1", "sha256": "", "parts": [ "EF" ] }""").ToJson();

        json.Should().Contain("\"schema\": 2").And.NotContain("repository").And.NotContain("sha256");
        var reread = KitJson.Parse(json);
        reread.ReadSchema.Should().Be(2);
        reread.Parts.Enable.Should().Equal("EF");
    }

    [Theory]
    [InlineData("""{ "schema": 3 }""", "schema")]
    [InlineData("""{ "schema": 2, "source": "cloud" }""", "cloud")]
    [InlineData("""{ "schema": 2, "parts": { "enabel": [ "EF" ] } }""", "enabel")]
    [InlineData("""{ "schema": 2, "filters": [ { "source": "nuget.org" } ] }""", "package")]
    [InlineData("""{ "schema": 2, "parts": { "enable": [ "EF" ], "disable": [ "EF" ] } }""", "'EF'")]
    [InlineData("""{ "repository": "DragoAnt/MSBuildKit", "parts": "EF" }""", "parts")]
    [InlineData("""{ }""", "schema")]
    [InlineData("""[ 1 ]""", "object")]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => KitJson.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitLayout.KitJsonFileName).And.Contain(mentioned);
    }
}
