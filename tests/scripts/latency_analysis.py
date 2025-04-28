#!/usr/bin/env python3
import json
import sys
import datetime
from datetime import timezone
from statistics import mean

def analyze_latency(filename):
    latencies_before_120s = []
    latencies_after_120s = []
    
    try:
        with open(filename, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"File not found: {filename}")
        return None
    
    # Parse each line as a JSON object
    entries = []
    for line in lines:
        try:
            line = line.strip()
            if line:  # Skip empty lines
                entry = json.loads(line)
                entries.append(entry)
        except json.JSONDecodeError:
            continue
    
    if not entries:
        print(f"No valid JSON entries found in {filename}")
        return None
        
    # Get the timestamp of the first request
    first_timestamp = datetime.datetime.fromisoformat(entries[0]['timestamp'].replace('Z', '+00:00'))
    
    # Categorize requests as before or after 120 seconds from the start
    for entry in entries:
        timestamp = datetime.datetime.fromisoformat(entry['timestamp'].replace('Z', '+00:00'))
        time_diff = (timestamp - first_timestamp).total_seconds()
        
        # Convert latency from nanoseconds to milliseconds
        latency_ms = entry['latency'] / 1_000_000
        
        if time_diff < 120:
            latencies_before_120s.append(latency_ms)
        else:
            latencies_after_120s.append(latency_ms)
    
    # Calculate averages
    avg_before_120s = mean(latencies_before_120s) if latencies_before_120s else 0
    avg_after_120s = mean(latencies_after_120s) if latencies_after_120s else 0
    
    return {
        'filename': filename,
        'avg_before_120s': avg_before_120s,
        'avg_after_120s': avg_after_120s,
        'count_before_120s': len(latencies_before_120s),
        'count_after_120s': len(latencies_after_120s)
    }

def main():
    files = [
        '/home/abraao/code/personal/zero-trust/tests/data-experiment-opa/normal.json',
        '/home/abraao/code/personal/zero-trust/tests/data-experiment-proxy/normal.json',
        '/home/abraao/code/personal/zero-trust/tests/data-experiment-opensearch/normal.json'
    ]
    
    print(f"Starting analysis of {len(files)} files...")
    
    results = []
    for file in files:
        print(f"Processing {file}...")
        try:
            result = analyze_latency(file)
            if result:
                results.append(result)
                print(f"Successfully analyzed {file}")
            else:
                print(f"Failed to analyze {file}")
        except Exception as e:
            print(f"Error processing {file}: {e}")
    
    # Display results
    print("\nLatency Analysis Results (in milliseconds):")
    print("-" * 110)
    print(f"{'File':<50} | {'Before 120s':<15} | {'After 120s':<15} | {'Samples Before':<15} | {'Samples After':<10}")
    print("-" * 110)
    
    for result in results:
        filename = result['filename'].split('/')[-2] + '/' + result['filename'].split('/')[-1]
        print(f"{filename:<50} | {result['avg_before_120s']:<15.3f} | {result['avg_after_120s']:<15.3f} | {result['count_before_120s']:<15} | {result['count_after_120s']:<10}")

if __name__ == "__main__":
    main() 