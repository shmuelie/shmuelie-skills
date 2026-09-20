namespace Fixture.Library.Tests;

[TestClass]
public sealed class Test1
{
    [TestMethod]
    public void TestMethod1()
    {
        Assert.AreEqual(-1, IntegerMath.Add(int.MaxValue, int.MinValue));
        Assert.AreEqual(-1, IntegerMath.Add(int.MinValue, int.MaxValue));
    }
}

[TestClass]
public sealed class IntegerMathTests
{
    [TestMethod]
    [DataRow(0, 0, 0)]
    [DataRow(7, 0, 7)]
    [DataRow(0, -7, -7)]
    [DataRow(2, 3, 5)]
    [DataRow(-2, -3, -5)]
    [DataRow(-7, 3, -4)]
    [DataRow(7, -3, 4)]
    [DataRow(int.MaxValue, 0, int.MaxValue)]
    [DataRow(int.MinValue, 0, int.MinValue)]
    [DataRow(int.MaxValue, -1, 2147483646)]
    [DataRow(int.MinValue, 1, -2147483647)]
    [DataRow(int.MaxValue, int.MinValue, -1)]
    public void Add_ReturnsExpectedSum(int left, int right, int expected)
    {
        Assert.AreEqual(expected, IntegerMath.Add(left, right));
        Assert.AreEqual(expected, IntegerMath.Add(right, left));
    }

    [TestMethod]
    [DataRow(int.MaxValue, 1)]
    [DataRow(1, int.MaxValue)]
    [DataRow(int.MinValue, -1)]
    [DataRow(-1, int.MinValue)]
    [DataRow(int.MaxValue, int.MaxValue)]
    [DataRow(int.MinValue, int.MinValue)]
    public void Add_ThrowsExactlyOverflowException(int left, int right)
    {
        Assert.ThrowsExactly<OverflowException>(() => IntegerMath.Add(left, right));
        Assert.ThrowsExactly<OverflowException>(() => IntegerMath.Add(right, left));
    }

    [TestMethod]
    [DataRow(0, 0, 0)]
    [DataRow(2, 3, 5)]
    [DataRow(-7, 3, -4)]
    [DataRow(int.MaxValue, -1, 2147483646)]
    [DataRow(int.MinValue, 1, -2147483647)]
    [DataRow(int.MaxValue, int.MinValue, -1)]
    public void Add_IsCommutative_WhenBothOrdersAreSafe(int left, int right, int expected)
    {
        int forward = IntegerMath.Add(left, right);
        int reverse = IntegerMath.Add(right, left);

        Assert.AreEqual(expected, forward);
        Assert.AreEqual(expected, reverse);
        Assert.AreEqual(forward, reverse);
    }
}
