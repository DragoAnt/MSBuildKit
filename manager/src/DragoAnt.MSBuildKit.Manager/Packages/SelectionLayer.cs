namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>The layers of the selection, in precedence order: a later layer wins per part.</summary>
public enum SelectionLayer
{
    Core,
    Company,
    Team,
    Repository,
}
