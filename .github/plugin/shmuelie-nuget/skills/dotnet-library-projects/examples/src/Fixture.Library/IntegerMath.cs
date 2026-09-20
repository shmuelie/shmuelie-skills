namespace Fixture.Library;

/// <summary>Small, platform-neutral API for the package-consumption example.</summary>
public static class IntegerMath
{
    /// <summary>Adds two integers without silently wrapping on overflow.</summary>
    /// <exception cref="OverflowException">The result cannot fit in an integer.</exception>
    public static int Add(int left, int right) => checked(left + right);
}
