using System.Text.Json;

namespace Synthetic.Core;

public sealed record Item(string Name);

public sealed class ItemAlreadyExistsException(string name)
    : Exception($"Item already exists: {name}");

public interface IItemStore
{
    Task<IReadOnlyList<Item>> ReadAsync(CancellationToken cancellationToken);
    Task WriteAsync(IReadOnlyList<Item> items, CancellationToken cancellationToken);
}

public sealed class ItemService(IItemStore store)
{
    public Task<IReadOnlyList<Item>> ListAsync(CancellationToken cancellationToken) =>
        store.ReadAsync(cancellationToken);

    public async Task<Item> AddAsync(string name, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        name = name.Trim();
        if (name.Length > 64)
            throw new ArgumentException("Name must be at most 64 characters.", nameof(name));

        var items = await store.ReadAsync(cancellationToken);
        if (items.Any(item => string.Equals(item.Name, name, StringComparison.OrdinalIgnoreCase)))
            throw new ItemAlreadyExistsException(name);

        var item = new Item(name);
        await store.WriteAsync([.. items, item], cancellationToken);
        return item;
    }
}

public sealed class JsonFileItemStore(string path) : IItemStore
{
    public async Task<IReadOnlyList<Item>> ReadAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!File.Exists(path))
            return [];

        var json = await File.ReadAllTextAsync(path, cancellationToken);
        return JsonSerializer.Deserialize<List<Item>>(json)
            ?? throw new InvalidDataException("Invalid item store.");
    }

    public async Task WriteAsync(IReadOnlyList<Item> items, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var pending = path + "." + Guid.NewGuid().ToString("N") + ".pending";
        try
        {
            await File.WriteAllTextAsync(pending, JsonSerializer.Serialize(items), cancellationToken);
            cancellationToken.ThrowIfCancellationRequested();
            File.Move(pending, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(pending))
                File.Delete(pending);
        }
    }
}
