using System;
using System.Collections.Generic;
using System.Linq;

namespace QuickLookExtended.Sample;

public sealed record Metric(string Name, int Count, IReadOnlyList<string> Tags);

public static class Program
{
    public static void Main()
    {
        var metrics = new[]
        {
            new Metric("preview.opened", 42, new[] { "quicklook", "text" }),
            new Metric("preview.highlighted", 17, new[] { "syntax", "csharp" }),
            new Metric("preview.fallback", 3, new[] { "plain", "large-file" })
        };

        foreach (var metric in metrics.OrderByDescending(item => item.Count))
        {
            Console.WriteLine($"{metric.Name}: {metric.Count}");
            Console.WriteLine($"tags: {string.Join(", ", metric.Tags)}");
        }
    }
}
