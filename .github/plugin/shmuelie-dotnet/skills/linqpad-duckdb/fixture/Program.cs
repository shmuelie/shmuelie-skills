using System.Text.Json;
using DuckDB.NET.Data;

var skipDelta = args.Length == 2 && args[1] == "--skip-delta";
if ((args.Length != 1 && !skipDelta) || !Directory.Exists(args[0]))
{
    Console.Error.WriteLine(
        "Pass an existing, user-owned parent directory and optionally --skip-delta.");
    return 64;
}

var outputRoot = Path.Combine(
    Path.GetFullPath(args[0]),
    $"linqpad-duckdb-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}");
Directory.CreateDirectory(outputRoot);

var parquetPath = Path.Combine(outputRoot, "physical.parquet");
var deltaPath = Path.Combine(outputRoot, "delta-table");
var deltaLogPath = Path.Combine(deltaPath, "_delta_log");
var deltaDataPath = Path.Combine(deltaPath, "part-00000.parquet");
var extensionPath = Path.Combine(outputRoot, "extensions");
Directory.CreateDirectory(deltaLogPath);
Directory.CreateDirectory(extensionPath);

using var db = new DuckDBConnection("Data Source=:memory:");
db.Open();

var duckDbVersion = Scalar(db, "SELECT version()");
var duckDbPlatform = Scalar(db, "PRAGMA platform");
Directory.CreateDirectory(Path.Combine(extensionPath, duckDbVersion, duckDbPlatform));

Console.WriteLine($"OUTPUT_ROOT={outputRoot}");
Console.WriteLine($"DUCKDB_VERSION={duckDbVersion}");
Console.WriteLine($"DUCKDB_PLATFORM={duckDbPlatform}");

Execute(
    db,
    """
    CREATE TABLE physical_data ("col-aaaa" INTEGER, "col-bbbb" VARCHAR);
    INSERT INTO physical_data VALUES (1, 'alpha'), (2, 'beta'), (3, 'gamma');
    """);
Execute(db, $"COPY physical_data TO {SqlLiteral(parquetPath)} (FORMAT parquet)");
Execute(db, $"COPY physical_data TO {SqlLiteral(deltaDataPath)} (FORMAT parquet)");

var physicalColumns = FirstColumn(
    db,
    $"SELECT column_name FROM (DESCRIBE SELECT * FROM read_parquet({SqlLiteral(parquetPath)}))");
Require(
    physicalColumns.SequenceEqual(["col-aaaa", "col-bbbb"]),
    $"Unexpected physical schema: {string.Join(", ", physicalColumns)}");

var selectedValues = FirstColumn(
    db,
    $"""
    SELECT "col-bbbb"
    FROM read_parquet({SqlLiteral(parquetPath)})
    WHERE "col-aaaa" >= 2
    ORDER BY "col-aaaa"
    """);
Require(
    selectedValues.SequenceEqual(["beta", "gamma"]),
    $"Unexpected Parquet selection: {string.Join(", ", selectedValues)}");
Console.WriteLine("PARQUET_RESULT=PASS physical=[col-aaaa,col-bbbb] selected=[beta,gamma]");

WriteDeltaLog(deltaLogPath, deltaDataPath);
if (skipDelta)
{
    Console.WriteLine("DELTA_RESULT=SKIPPED no network or extension installation requested");
    return 0;
}

Execute(db, $"SET extension_directory = {SqlLiteral(extensionPath)}");

try
{
    Execute(db, "INSTALL delta");
    Execute(db, "LOAD delta");

    var logicalColumns = FirstColumn(
        db,
        $"SELECT column_name FROM (DESCRIBE SELECT * FROM delta_scan({SqlLiteral(deltaPath)}))");
    Require(
        logicalColumns.SequenceEqual(["id", "code"]),
        $"Unexpected logical Delta schema: {string.Join(", ", logicalColumns)}");

    var logicalValues = FirstColumn(
        db,
        $"""
        SELECT code
        FROM delta_scan({SqlLiteral(deltaPath)})
        WHERE id >= 2
        ORDER BY id
        """);
    Require(
        logicalValues.SequenceEqual(["beta", "gamma"]),
        $"Unexpected Delta selection: {string.Join(", ", logicalValues)}");
    Console.WriteLine("DELTA_RESULT=PASS logical=[id,code] selected=[beta,gamma]");
    return 0;
}
catch (DuckDBException ex)
{
    Console.Error.WriteLine($"DELTA_RESULT=UNAVAILABLE_OR_UNSUPPORTED {Sanitize(ex.Message)}");
    return 2;
}

static void WriteDeltaLog(string logPath, string dataPath)
{
    var schema = new
    {
        type = "struct",
        fields = new object[]
        {
            new
            {
                name = "id",
                type = "integer",
                nullable = true,
                metadata = new Dictionary<string, object>
                {
                    ["delta.columnMapping.physicalName"] = "col-aaaa",
                    ["delta.columnMapping.id"] = 1,
                },
            },
            new
            {
                name = "code",
                type = "string",
                nullable = true,
                metadata = new Dictionary<string, object>
                {
                    ["delta.columnMapping.physicalName"] = "col-bbbb",
                    ["delta.columnMapping.id"] = 2,
                },
            },
        },
    };

    var actions = new object[]
    {
        new
        {
            metaData = new
            {
                id = "00000000-0000-0000-0000-000000000014",
                format = new { provider = "parquet", options = new { } },
                schemaString = JsonSerializer.Serialize(schema),
                partitionColumns = Array.Empty<string>(),
                configuration = new Dictionary<string, string>
                {
                    ["delta.columnMapping.mode"] = "name",
                    ["delta.columnMapping.maxColumnId"] = "2",
                },
                createdTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            },
        },
        new
        {
            protocol = new
            {
                minReaderVersion = 3,
                minWriterVersion = 7,
                readerFeatures = new[] { "columnMapping" },
                writerFeatures = new[] { "columnMapping" },
            },
        },
        new
        {
            add = new
            {
                path = Path.GetFileName(dataPath),
                partitionValues = new Dictionary<string, string>(),
                size = new FileInfo(dataPath).Length,
                modificationTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                dataChange = true,
            },
        },
    };

    var lines = actions.Select(action => JsonSerializer.Serialize(action));
    File.WriteAllText(
        Path.Combine(logPath, "00000000000000000000.json"),
        string.Join(Environment.NewLine, lines) + Environment.NewLine);
}

static void Execute(DuckDBConnection db, string sql)
{
    using var command = db.CreateCommand();
    command.CommandText = sql;
    command.ExecuteNonQuery();
}

static string Scalar(DuckDBConnection db, string sql)
{
    using var command = db.CreateCommand();
    command.CommandText = sql;
    return Convert.ToString(command.ExecuteScalar()) ?? "<null>";
}

static List<string> FirstColumn(DuckDBConnection db, string sql)
{
    using var command = db.CreateCommand();
    command.CommandText = sql;
    using var reader = command.ExecuteReader();
    var result = new List<string>();
    while (reader.Read())
    {
        result.Add(reader.GetString(0));
    }

    return result;
}

static string SqlLiteral(string value) => $"'{value.Replace('\\', '/').Replace("'", "''")}'";

static string Sanitize(string value) =>
    value.Replace(Environment.NewLine, " ", StringComparison.Ordinal).Trim();

static void Require(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}
