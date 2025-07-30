import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import json
import numpy as np

# Load and process JSON files
def process_experiment(file_path, experiment_name):
    with open(file_path, "r") as f:
        data = [json.loads(line) for line in f]

    # Convert to DataFrame
    df = pd.DataFrame(data)

    # Parse timestamp and calculate time since start
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['time_since_start'] = (df['timestamp'] - df['timestamp'].min()).dt.total_seconds()

    # Map codes: 200 stays 200, all others become 429
    df['code'] = df['code'].apply(lambda x: 200 if x == 200 else 429)

    # Aggregate latency by 5-second intervals
    df['time_bin'] = (df['time_since_start'] // 5) * 5
    agg_df = df.groupby(['time_bin', 'code'])['latency'].mean().reset_index()

    agg_df['experiment'] = experiment_name
    return agg_df

# File paths and experiment names
experiments = {
    "../data-experiment-proxy/envoy-scenario.json": "Proxy",
    "../data-experiment-opa/opa-scenario.json": "Motor de Políticas",
    "../data-experiment-opensearch/opensearch-scenario.json": "Motor de logs"
}

# Accepted requests data
accepted_after_attack = {
    'Proxy': 14400,
    'Motor de Políticas': 148,
    'Motor de logs': 2053
}

# Process all experiments
all_data = []
for file_path, exp_name in experiments.items():
    all_data.append(process_experiment(file_path, exp_name))

# Combine all data into one DataFrame
combined_df = pd.concat(all_data)

# Plotting
fig, ax = plt.subplots(figsize=(12, 6))

# Colorblind-friendly colors: Blue for success (200), Orange for errors (429)
colors = {200: '#0072B2', 429: '#E69F00'}  
experiment_styles = {'Proxy': '-', 'Motor de Políticas': '--', 'Motor de logs': ':'}

# Track maximum latency to use for arrow placement
max_latency = 0

for experiment, exp_data in combined_df.groupby('experiment'):
    for code, code_data in exp_data.groupby('code'):
        code_data['latency_ms'] = code_data['latency'] / 1_000_000
        
        # Update max latency if needed
        current_max = code_data['latency_ms'].max()
        if current_max > max_latency:
            max_latency = current_max

        ax.plot(
            code_data['time_bin'], 
            code_data['latency_ms'], 
            label=f"{experiment} - {code}", 
            color=colors[code], 
            linestyle=experiment_styles[experiment]
        )

# ** Add Background Shading After 120 Seconds **
ax.axvspan(120, 480, color='#DADAEB', alpha=0.4, label="Área de ataque")  # Lighter, more neutral shade
ax.set_xlim(0, 480)

# Set x-axis ticks every 20 seconds
x_ticks = np.arange(0, 481, 20)
ax.set_xticks(x_ticks)

# Now add the arrow and text for attack start - after plotting is done
attack_x = 120  # Time when attack starts
arrow_y = max_latency * 1.1  # Place above the highest point in the plot

# Make sure we set a y-limit that includes space for the annotation
ax.set_ylim(0, max_latency * 1.2)

# Add the annotation
ax.annotate('Início do ataque', 
            xy=(attack_x, max_latency * 0.7),  # Point to the middle of the plot at attack time
            xytext=(attack_x, arrow_y),  # Text above the plot
            va='center', 
            ha='center',
            fontsize=10,
            fontweight='bold',
            color='black',
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="black", alpha=0.9),
            arrowprops=dict(
                arrowstyle="->",
                color='black',
                linewidth=1.5,
                connectionstyle="arc3,rad=0.0"
            ))

# Custom legend for codes
code_legend = [
    Line2D([0], [0], color=colors[200], lw=2, label='200'),
    Line2D([0], [0], color=colors[429], lw=2, label='429')
]

# Custom legend for line styles with request counts
style_legend = [
    Line2D([0], [0], color='black', lw=2, linestyle='-', 
           label=f'Proxy - {accepted_after_attack["Proxy"]} requisições'),
    Line2D([0], [0], color='black', lw=2, linestyle=':', 
        label=f'Motor de logs - {accepted_after_attack["Motor de logs"]} requisições'),
    Line2D([0], [0], color='black', lw=2, linestyle='--', 
           label=f'Motor de Políticas - {accepted_after_attack["Motor de Políticas"]} requisições'),

]

# Add titles, labels, and legends
ax.set_xlabel('Tempo (s)', fontsize=14, fontweight='bold')
ax.set_ylabel('Latência Média (ms)', fontsize=14, fontweight='bold')
ax.grid(True)

# Add legend for codes
legend1 = ax.legend(handles=code_legend, loc='upper left', title='Status HTTP', fontsize=14, title_fontsize=14)
legend2 = ax.legend(handles=style_legend, loc='upper right', title='Experimentos - Requisições aceitas após ataque', fontsize=12, title_fontsize=14)
ax.add_artist(legend1)  # Ensure the first legend is not overwritten

plt.tight_layout()
# Save the plot as a PNG file
plt.savefig("experiment_latency_plot.png", format="png", dpi=300)

# Optional: Inform where the file is saved
print("Plot saved as 'experiment_latency_plot.png'")

