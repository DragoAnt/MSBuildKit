using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Packages;

public sealed class SelectionTests
{
    private const string CompanyId = "Contoso.MSBuildKit";
    private const string TeamId = "Contoso.Web.MSBuildKit";

    private static readonly KitCatalog Catalog = new(
    [
        Part("Core", KitPartKind.Required, 0),
        Part("Trunk", KitPartKind.Required, 10),
        Part("Vcs.GitHub", KitPartKind.Default, 20),
        Part("Testing", KitPartKind.Default, 30),
        Part("Locals.Secrets", KitPartKind.Default, 40),
        Part("Project.RoslynComponent", KitPartKind.Optional, 50),
        Part("Project.CodeAnalyzer", KitPartKind.Optional, 60, "Project.RoslynComponent"),
        Part("Project.CodeFixer", KitPartKind.Optional, 70, "Project.RoslynComponent", "Project.CodeAnalyzer"),
        Part("EF", KitPartKind.Optional, 80),
        Part("Vcs.GitLab", KitPartKind.Optional, 90),
    ]);

    [Fact]
    public void CoreDefaults_RequiredAndDefaultOn_OptionalOff()
    {
        var result = Selection.Compute(Catalog, [], PartToggles.Empty);

        result.Parts.Select(p => p.Id).Should().Equal(Catalog.Parts.Select(p => p.Id));
        result.Parts.Should().OnlyContain(p => p.DecidedBy == SelectionLayer.Core && p.RequiredBy == null && !p.Locked);
        result.EnabledParts.Select(p => p.Id).Should().Equal("Core", "Trunk", "Vcs.GitHub", "Testing", "Locals.Secrets");
        result.Company.Should().BeNull();
        result.Team.Should().BeNull();
    }

    [Theory]
    [InlineData(SelectionLayer.Company)]
    [InlineData(SelectionLayer.Team)]
    [InlineData(SelectionLayer.Repository)]
    public void EachLayer_EnablesAndDisables(SelectionLayer layer)
    {
        var toggles = new PartToggles(Enable: ["EF"], Disable: ["Vcs.GitHub"]);

        var result = layer switch
        {
            SelectionLayer.Company => Selection.Compute(Catalog, [Company(enable: toggles.Enable, disable: toggles.Disable)], PartToggles.Empty),
            SelectionLayer.Team => Selection.Compute(Catalog, [Company(), Team(enable: toggles.Enable, disable: toggles.Disable)], PartToggles.Empty),
            _ => Selection.Compute(Catalog, [Company(), Team()], toggles),
        };

        result.Decision("EF").Should().Match<PartDecision>(d => d.Enabled && d.DecidedBy == layer);
        result.Decision("Vcs.GitHub").Should().Match<PartDecision>(d => !d.Enabled && d.DecidedBy == layer);
        result.Decision("Testing").DecidedBy.Should().Be(SelectionLayer.Core);
    }

    [Fact]
    public void LaterLayer_WinsPerPart()
    {
        var result = Selection.Compute(Catalog,
            [
                Company(enable: ["EF", "Vcs.GitLab"], disable: ["Vcs.GitHub", "Testing"]),
                Team(enable: ["Vcs.GitHub"], disable: ["EF"]),
            ],
            new PartToggles(Enable: ["EF"], Disable: ["Vcs.GitLab"]));

        result.Decision("EF").Should().Match<PartDecision>(d => d.Enabled && d.DecidedBy == SelectionLayer.Repository);
        result.Decision("Vcs.GitLab").Should().Match<PartDecision>(d => !d.Enabled && d.DecidedBy == SelectionLayer.Repository);
        result.Decision("Vcs.GitHub").Should().Match<PartDecision>(d => d.Enabled && d.DecidedBy == SelectionLayer.Team);
        result.Decision("Testing").Should().Match<PartDecision>(d => !d.Enabled && d.DecidedBy == SelectionLayer.Company);
        result.Decision("Locals.Secrets").Should().Match<PartDecision>(d => d.Enabled && d.DecidedBy == SelectionLayer.Core);
    }

    [Theory]
    [InlineData(SelectionLayer.Company, "Core")]
    [InlineData(SelectionLayer.Team, "Trunk")]
    [InlineData(SelectionLayer.Repository, "Core")]
    public void RequiredPart_IsNeverDisabled(SelectionLayer layer, string part)
    {
        var act = () => ComputeWithLayer(layer, disable: [part]);

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(layer);
        error.Message.Should().Contain($"'{part}'").And.Contain("required");
    }

    [Theory]
    [InlineData(SelectionLayer.Team, true)]
    [InlineData(SelectionLayer.Team, false)]
    [InlineData(SelectionLayer.Repository, true)]
    [InlineData(SelectionLayer.Repository, false)]
    public void CompanyLockedPart_IsRefusedForTeamAndRepository(SelectionLayer layer, bool disable)
    {
        var company = Company(locked: ["Locals.Secrets"]);
        PartToggles toggles = disable ? new([], ["Locals.Secrets"]) : new(["Locals.Secrets"], []);

        var act = () => layer == SelectionLayer.Team
            ? Selection.Compute(Catalog, [company, Team(enable: toggles.Enable, disable: toggles.Disable)], PartToggles.Empty)
            : Selection.Compute(Catalog, [company, Team()], toggles);

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(layer);
        error.Message.Should().Contain("'Locals.Secrets'").And.Contain("locked").And.Contain(CompanyId);
    }

    [Fact]
    public void CompanyLockedPart_KeepsTheCompanyDecision()
    {
        var result = Selection.Compute(Catalog, [Company(disable: ["EF"], locked: ["EF", "Testing"])], PartToggles.Empty);

        result.Decision("EF").Should().Match<PartDecision>(d => !d.Enabled && d.Locked && d.DecidedBy == SelectionLayer.Company);
        result.Decision("Testing").Should().Match<PartDecision>(d => d.Enabled && d.Locked && d.DecidedBy == SelectionLayer.Core);
    }

    [Fact]
    public void Requires_IsClosedTransitively()
    {
        var result = Selection.Compute(Catalog, [], new PartToggles(Enable: ["Project.CodeFixer"], Disable: []));

        result.Decision("Project.CodeFixer").Should().Match<PartDecision>(d => d.Enabled && d.RequiredBy == null);
        result.Decision("Project.CodeAnalyzer").Should().Match<PartDecision>(
            d => d.Enabled && d.RequiredBy == "Project.CodeFixer" && d.DecidedBy == SelectionLayer.Repository);
        result.Decision("Project.RoslynComponent").Should().Match<PartDecision>(d => d.Enabled && d.RequiredBy != null);
    }

    [Fact]
    public void Requires_OfAPartAnotherLayerDisabled_Throws()
    {
        var act = () => Selection.Compute(Catalog,
            [Company(disable: ["Project.RoslynComponent"])],
            new PartToggles(Enable: ["Project.CodeAnalyzer"], Disable: []));

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(SelectionLayer.Repository);
        error.Message.Should().Contain("'Project.CodeAnalyzer'").And.Contain("'Project.RoslynComponent'").And.Contain(CompanyId);
    }

    [Theory]
    [InlineData(SelectionLayer.Company, "enable")]
    [InlineData(SelectionLayer.Company, "disable")]
    [InlineData(SelectionLayer.Company, "locked")]
    [InlineData(SelectionLayer.Team, "enable")]
    [InlineData(SelectionLayer.Team, "disable")]
    [InlineData(SelectionLayer.Repository, "enable")]
    [InlineData(SelectionLayer.Repository, "disable")]
    public void UnknownPart_Throws_NamingTheLayer(SelectionLayer layer, string list)
    {
        string[] unknown = ["Nope"];

        var act = () => list switch
        {
            "enable" => ComputeWithLayer(layer, enable: unknown),
            "disable" => ComputeWithLayer(layer, disable: unknown),
            _ => Selection.Compute(Catalog, [Company(locked: unknown)], PartToggles.Empty),
        };

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(layer);
        error.Message.Should().Contain("'Nope'").And.Contain("unknown");
    }

    [Fact]
    public void RepositoryEnablingAndDisablingOnePart_Throws()
    {
        var act = () => Selection.Compute(Catalog, [], new PartToggles(Enable: ["EF"], Disable: ["EF"]));

        act.Should().Throw<SelectionException>().Which.Layer.Should().Be(SelectionLayer.Repository);
    }

    [Fact]
    public void TwoCompanyFilters_Throw()
    {
        var act = () => Selection.Compute(Catalog, [Company(), Company("Fabrikam.MSBuildKit")], PartToggles.Empty);

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(SelectionLayer.Company);
        error.Message.Should().Contain(CompanyId).And.Contain("Fabrikam.MSBuildKit");
    }

    [Fact]
    public void TwoTeamFilters_Throw()
    {
        var act = () => Selection.Compute(Catalog, [Company(), Team(), Team(id: "Contoso.Api.MSBuildKit")], PartToggles.Empty);

        act.Should().Throw<SelectionException>().Which.Layer.Should().Be(SelectionLayer.Team);
    }

    [Fact]
    public void TeamFilter_NotExtendingTheAttachedCompany_Throws()
    {
        var act = () => Selection.Compute(Catalog, [Company(), Team(extends: "Fabrikam.MSBuildKit")], PartToggles.Empty);

        var error = act.Should().Throw<SelectionException>().Which;
        error.Layer.Should().Be(SelectionLayer.Team);
        error.Message.Should().Contain(TeamId).And.Contain("Fabrikam.MSBuildKit").And.Contain(CompanyId);
    }

    [Fact]
    public void TeamFilter_WithoutACompany_Throws()
    {
        var act = () => Selection.Compute(Catalog, [Team()], PartToggles.Empty);

        act.Should().Throw<SelectionException>().Which.Message.Should().Contain(TeamId).And.Contain(CompanyId);
    }

    [Fact]
    public void TeamFilter_ExtendsComparesIdsIgnoringCase()
    {
        var result = Selection.Compute(Catalog, [Company(), Team(extends: CompanyId.ToLowerInvariant())], PartToggles.Empty);

        result.Team!.PackageId.Should().Be(TeamId);
    }

    [Fact]
    public void FilterPackages_AreCollectedCompanyFirst()
    {
        var company = new AttachedFilter(CompanyId, Filter(KitTier.Company, null, packages: [new KitFilterPackage("Contoso.MSBuildKit.Signing", "[1.0.0, 2.0.0)")]));
        var team = new AttachedFilter(TeamId, Filter(KitTier.Team, CompanyId, packages: [new KitFilterPackage("Contoso.Web.MSBuildKit.Pages", null)]));

        var result = Selection.Compute(Catalog, [team, company], PartToggles.Empty);

        result.Company!.PackageId.Should().Be(CompanyId);
        result.Team!.PackageId.Should().Be(TeamId);
        result.Packages.Select(p => p.Id).Should().Equal("Contoso.MSBuildKit.Signing", "Contoso.Web.MSBuildKit.Pages");
    }

    private static SelectionResult ComputeWithLayer(SelectionLayer layer, string[]? enable = null, string[]? disable = null) => layer switch
    {
        SelectionLayer.Company => Selection.Compute(Catalog, [Company(enable: enable, disable: disable)], PartToggles.Empty),
        SelectionLayer.Team => Selection.Compute(Catalog, [Company(), Team(enable: enable, disable: disable)], PartToggles.Empty),
        _ => Selection.Compute(Catalog, [Company(), Team()], new PartToggles(enable ?? [], disable ?? [])),
    };

    private static KitCatalogPart Part(string id, KitPartKind kind, int order, params string[] requires) => new(id, kind, order, requires);

    private static AttachedFilter Company(
        string id = CompanyId, IReadOnlyList<string>? enable = null, IReadOnlyList<string>? disable = null, IReadOnlyList<string>? locked = null) =>
        new(id, Filter(KitTier.Company, null, enable, disable, locked));

    private static AttachedFilter Team(
        string id = TeamId, string extends = CompanyId, IReadOnlyList<string>? enable = null, IReadOnlyList<string>? disable = null) =>
        new(id, Filter(KitTier.Team, extends, enable, disable));

    private static KitFilter Filter(
        KitTier tier, string? extends, IReadOnlyList<string>? enable = null, IReadOnlyList<string>? disable = null,
        IReadOnlyList<string>? locked = null, IReadOnlyList<KitFilterPackage>? packages = null) =>
        new(tier, "fixture", extends, [], packages ?? [], new KitFilterParts(enable ?? [], disable ?? [], locked ?? []), null);
}
