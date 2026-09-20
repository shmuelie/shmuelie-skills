using Fixture.Library;

if (IntegerMath.Add(2, 3) != 5)
    throw new InvalidOperationException("The packed library did not return the expected result.");
Console.WriteLine("Consumed the packed library successfully.");
