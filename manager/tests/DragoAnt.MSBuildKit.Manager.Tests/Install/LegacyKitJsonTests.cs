using DragoAnt.MSBuildKit.Manager.Install;
using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Install;

public sealed class LegacyKitJsonTests
{
    [Fact]
    public void Parse_SingleLineParts_ReadsEveryField()
    {
        var kit = LegacyKitJson.Parse("""
            {
              "repository": "DragoAnt/MSBuildKit",
              "version": "0.2.1",
              "sha256": "ab12",
              "parts": ["EF","PackageAsProj"]
            }
            """);

        kit.Repository.Should().Be("DragoAnt/MSBuildKit");
        kit.Version.Should().Be("0.2.1");
        kit.Sha256.Should().Be("ab12");
        kit.Parts.Should().Equal("EF", "PackageAsProj");
    }

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    public void Parse_MultiLinePartsArray_KeepsEveryPart(string newline)
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

        var kit = LegacyKitJson.Parse(text);

        kit.Parts.Should().Equal("Project.RoslynComponent", "Project.CodeAnalyzer", "EF");
    }

    [Fact]
    public void Parse_EmptyParts_ReadsNoPart()
    {
        var kit = LegacyKitJson.Parse("""{ "repository": "DragoAnt/MSBuildKit", "version": "0.0.1", "sha256": "", "parts": [] }""");

        kit.Version.Should().Be("0.0.1");
        kit.Parts.Should().BeEmpty();
    }

    [Fact]
    public void Parse_WithoutParts_ReadsNoPart()
    {
        var kit = LegacyKitJson.Parse("""{ "repository": "DragoAnt/MSBuildKit", "version": "0.1.1" }""");

        kit.Sha256.Should().BeNull();
        kit.Parts.Should().BeEmpty();
    }

    [Fact]
    public void Parse_AcceptsCommentsAndTrailingCommas()
    {
        var kit = LegacyKitJson.Parse("""
            {
              // hand-edited
              "version": "0.2.0",
              "parts": [ "EF", ],
            }
            """);

        kit.Parts.Should().Equal("EF");
    }

    [Theory]
    [InlineData("""{ "schema": 2, "parts": [ "EF" ] }""", "not a kit.json written by update.sh")]
    [InlineData("""{ "schema": 1, "version": "0.2.1" }""", "not a kit.json written by update.sh")]
    [InlineData("""{ "repository": "DragoAnt/MSBuildKit", "parts": "EF" }""", "parts")]
    [InlineData("""{ "version": "0.2.1", "filters": [] }""", "filters")]
    [InlineData("""{ }""", "not a kit.json written by update.sh")]
    [InlineData("""[ 1 ]""", "object")]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => LegacyKitJson.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitLayout.LegacyKitJsonFileName).And.Contain(mentioned);
    }
}
