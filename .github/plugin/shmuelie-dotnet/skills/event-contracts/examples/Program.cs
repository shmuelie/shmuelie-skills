using System.Diagnostics.Tracing;
using System.Text.Json;

using var listener = new ContractListener();
using var source = new ImportEvents();
if (args.Contains("--wait-for-enter", StringComparer.Ordinal))
{
    Console.WriteLine($"PID {Environment.ProcessId}; enable {ImportEvents.ProviderName}, then press Enter.");
    Console.ReadLine();
}

Guid operation = Guid.NewGuid(), first = Guid.NewGuid(), second = Guid.NewGuid();
var before = EventSource.CurrentThreadActivityId;
Emit(operation, () => source.OperationBegin(4));
Emit(operation, () => source.AttemptLinked(first, 1));
Emit(first, () => source.AttemptFinished(1, "Failed", 0, false, 0, "TransportUnavailable"));
Emit(operation, () => source.AttemptLinked(second, 2));
Emit(second, () => source.AttemptFinished(2, "Failed", 2, true, 5, "SyntheticAccessDenied"));
Emit(operation, () => source.OperationFinished("Partial", 2, 4));
Require(EventSource.CurrentThreadActivityId == before, "Thread activity was not restored.");

var events = listener.Events;
Require(events.Count == 6, "Unexpected event count or EventSource schema error.");
Require(events.All(e => e.Id > 0 && e.Version == 1), "Invalid event metadata.");
Require(events.Select(e => e.Name).SequenceEqual(new[]
{
    "OperationBegin", "AttemptLinked", "AttemptFinished",
    "AttemptLinked", "AttemptFinished", "OperationFinished"
}), "Event order/names changed.");
Require(events[0].Activity == operation && events[5].Activity == operation, "Operation correlation failed.");
Require(events[1].Activity == operation && events[1].Related == first, "First transfer failed.");
Require(events[3].Activity == operation && events[3].Related == second, "Retry transfer failed.");
Require(first != second && events[2].Activity == first && events[4].Activity == second, "Attempt identity failed.");
Require(events[1].Opcode == EventOpcode.Send && events[3].Opcode == EventOpcode.Send, "Transfer opcode changed.");
Require(events[2].Fields["attempt"] is int attempt && attempt == 1, "Attempt is not a typed integer.");
Require(events[2].Fields["hasNativeCode"] is bool hasCode && !hasCode, "Unknown code became success.");
Require(events[2].Fields["nativeCode"] is int code && code == 0, "Unknown-code representation changed.");
Require(events[4].Fields["hasNativeCode"] is true && events[4].Fields["nativeCode"] is int native && native == 5,
    "Known native code was lost.");
Require(events[4].Fields["completed"] is int partial && partial == 2, "Partial progress was lost.");
Require((string?)events[5].Fields["outcome"] == "Partial" &&
    events[5].Fields["completed"] is int completed && completed == 2 &&
    events[5].Fields["total"] is int total && total == 4, "Terminal contract is inconsistent.");
foreach (var item in events)
    Console.WriteLine(JsonSerializer.Serialize(item));
Console.WriteLine("Synthetic event contract passed; no external operation was performed.");

static void Emit(Guid activity, Action write)
{
    EventSource.SetCurrentThreadActivityId(activity, out var prior);
    try { write(); }
    finally { EventSource.SetCurrentThreadActivityId(prior); }
}

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

[EventSource(Name = ProviderName)]
sealed class ImportEvents : EventSource
{
    public const string ProviderName = "Fabrikam-Synthetic-Import";

    [Event(1, Version = 1, Level = EventLevel.Informational)]
    public void OperationBegin(int total) => WriteEvent(1, total);

    [Event(2, Version = 1, Level = EventLevel.Informational, Task = (EventTask)1, Opcode = EventOpcode.Send)]
    public void AttemptLinked(Guid relatedActivityId, int attempt) =>
        WriteEventWithRelatedActivityId(2, relatedActivityId, attempt);

    [Event(3, Version = 1, Level = EventLevel.Warning)]
    public void AttemptFinished(int attempt, string outcome, int completed, bool hasNativeCode, int nativeCode, string errorCategory) =>
        WriteEvent(3, new object[] { attempt, outcome, completed, hasNativeCode, nativeCode, errorCategory });

    [Event(4, Version = 1, Level = EventLevel.Informational)]
    public void OperationFinished(string outcome, int completed, int total) =>
        WriteEvent(4, new object[] { outcome, completed, total });
}

sealed record CapturedEvent(int Id, string Name, byte Version, EventOpcode Opcode,
    Guid Activity, Guid Related, Dictionary<string, object?> Fields);

sealed class ContractListener : EventListener
{
    public List<CapturedEvent> Events { get; } = new();

    protected override void OnEventSourceCreated(EventSource eventSource)
    {
        if (eventSource.Name == ImportEvents.ProviderName)
            EnableEvents(eventSource, EventLevel.Verbose, EventKeywords.All);
    }

    protected override void OnEventWritten(EventWrittenEventArgs data)
    {
        var fields = new Dictionary<string, object?>(StringComparer.Ordinal);
        if (data.PayloadNames is not null && data.Payload is not null)
            for (var i = 0; i < data.PayloadNames.Count; i++)
                fields.Add(data.PayloadNames[i], data.Payload[i]);
        Events.Add(new(data.EventId, data.EventName ?? "", data.Version, data.Opcode,
            data.ActivityId, data.RelatedActivityId, fields));
    }
}
