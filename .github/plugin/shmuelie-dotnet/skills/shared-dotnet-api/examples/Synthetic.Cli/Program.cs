using System.Text.Json;
using Synthetic.Core;

using var source = new CancellationTokenSource();
Console.CancelKeyPress += Cancel;
try
{
    return await Cli.RunAsync(args, Console.Out, Console.Error, source.Token);
}
finally
{
    Console.CancelKeyPress -= Cancel;
}

void Cancel(object? sender, ConsoleCancelEventArgs e)
{
    e.Cancel = true;
    source.Cancel();
}

public static class Cli
{
    public static async Task<int> RunAsync(
        string[] args, TextWriter output, TextWriter error, CancellationToken cancellationToken)
    {
        try
        {
            if (args.Length == 0 || args[0] is not ("list" or "add"))
                throw new ArgumentException("Expected 'list' or 'add'.");

            string? file = null;
            string? name = null;
            var json = false;
            for (var i = 1; i < args.Length; i++)
            {
                switch (args[i])
                {
                    case "--file" when i + 1 < args.Length && file is null:
                        file = args[++i];
                        break;
                    case "--name" when i + 1 < args.Length && name is null && args[0] == "add":
                        name = args[++i];
                        break;
                    case "--json" when !json:
                        json = true;
                        break;
                    default:
                        throw new ArgumentException($"Invalid option: {args[i]}");
                }
            }

            if (string.IsNullOrWhiteSpace(file) || (args[0] == "add" && name is null))
                throw new ArgumentException("Expected --file PATH and, for add, --name NAME.");

            var service = new ItemService(new JsonFileItemStore(file));
            if (args[0] == "list")
            {
                var items = await service.ListAsync(cancellationToken);
                cancellationToken.ThrowIfCancellationRequested();
                if (json)
                    output.WriteLine(JsonSerializer.Serialize(items));
                else
                    foreach (var item in items)
                        output.WriteLine(item.Name);
            }
            else
            {
                var item = await service.AddAsync(name!, cancellationToken);
                output.WriteLine(json ? JsonSerializer.Serialize(item) : $"Added: {item.Name}");
            }

            return 0;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            error.WriteLine("Cancelled.");
            return 130;
        }
        catch (ArgumentException)
        {
            error.WriteLine("Invalid input. Usage: list --file PATH [--json] | add --file PATH --name NAME [--json]");
            return 2;
        }
        catch (ItemAlreadyExistsException)
        {
            error.WriteLine("Item already exists.");
            return 3;
        }
        catch (Exception)
        {
            error.WriteLine("Store operation failed.");
            return 1;
        }
    }
}
