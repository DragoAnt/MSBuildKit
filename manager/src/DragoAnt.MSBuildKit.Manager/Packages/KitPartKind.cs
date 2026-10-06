namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>How a core part is selected when no layer names it.</summary>
internal enum KitPartKind
{
    /// <summary>Always on; no layer may disable it.</summary>
    Required,

    /// <summary>On unless a layer disables it.</summary>
    Default,

    /// <summary>Off unless a layer enables it.</summary>
    Optional,
}
