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
    
    # Print debug info about the data
    print(f"File: {file_path}")
    print(f"Column types: {df.dtypes}")
    if 'code' in df:
        print(f"Unique codes: {df['code'].unique()}")
        print(f"Code type: {type(df['code'].iloc[0])}")
        # Convert code to string if it's not already
        df['code'] = df['code'].astype(str)
        print(f"After conversion - unique codes: {df['code'].unique()}")

    # Parse timestamp and calculate time since start
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['time_since_start'] = (df['timestamp'] - df['timestamp'].min()).dt.total_seconds()

    # Aggregate latency by 1-second intervals and include code values
    df['time_bin'] = (df['time_since_start'] // 5) * 5
    
    # Group by time_bin and code
    agg_df = df.groupby(['time_bin', 'code'])['latency'].mean().reset_index()
    
    agg_df['experiment'] = experiment_name
    return agg_df

# File paths and experiment names
experiments = {
    "../data-experiment-proxy/normal.json": "Normal",
    "../data-experiment-proxy/anomalous.json": "Anômalo"
}

# Process all experiments
all_data = []
for file_path, exp_name in experiments.items():
    all_data.append(process_experiment(file_path, exp_name))

# Combine all data into one DataFrame
combined_df = pd.concat(all_data)

# Set figure background to white explicitly
plt.rcParams['figure.facecolor'] = 'white'
plt.rcParams['axes.facecolor'] = 'white'

# Plotting
fig, ax = plt.subplots(figsize=(16, 10), facecolor='white')
ax.set_facecolor('white')

# Colorblind-friendly color palette with high contrast
# Specifically using blue for 200 and orange for 429
colors_by_code = {
    '200': '#0072B2',  # Blue 
    '429': '#E69F00',  # Orange
    '403': '#009E73',  # Green
    '404': '#CC79A7',  # Pink
    '500': '#F0E442',  # Yellow
    '502': '#56B4E9',  # Sky Blue
    '503': '#D55E00',  # Vermilion
    '504': '#666666',  # Gray
}

# Line styles for normal vs anomalous
line_styles = {
    'Normal': '-',      # Solid line
    'Anômalo': ':',  # Dashed line
}

# Line widths
line_widths = {
    '200': 4.5,  # Thicker line for 200 responses
    '429': 4.5,  # Thicker line for 429 responses
}

# Default values
default_color = '#999999'  # Gray
default_width = 3.5

# Track the unique codes that appear in the data
encountered_codes = set()

# Print debugging info about combined dataframe
print("\nCombined dataframe information:")
print(f"Unique experiments: {combined_df['experiment'].unique()}")
print(f"Unique codes: {combined_df['code'].unique()}")
print(f"Data for groupby operation: {combined_df.groupby(['experiment', 'code']).size()}")

# Track maximum latency for annotation positioning
max_latency = 0

# Plot each experiment-code combination with debugging info
for (experiment, code), group_data in combined_df.groupby(['experiment', 'code']):
    # Convert latency from nanoseconds to milliseconds
    group_data['latency_ms'] = group_data['latency'] / 1_000_000
    
    # Update max latency if needed
    current_max = group_data['latency_ms'].max()
    if current_max > max_latency:
        max_latency = current_max
    
    color = colors_by_code.get(code, default_color)
    linestyle = line_styles[experiment]
    linewidth = line_widths.get(code, default_width)
    
    # Debug print
    print(f"Plotting {experiment} with code {code}, color {color}, style {linestyle}")
    
    # Add the code to our set of encountered codes
    encountered_codes.add(code)
    
    ax.plot(
        group_data['time_bin'], 
        group_data['latency_ms'],
        linestyle=linestyle,
        linewidth=linewidth,
        color=color,
        label=f"{experiment} (Code {code})"
    )

print(f"Encountered codes: {encountered_codes}")

# ** Add Background Shading After 120 Seconds **
attack_x = 120  # Time when attack starts
ax.axvspan(attack_x, 480, color='#DADAEB', alpha=0.4, label="Área de ataque")  # Lighter, more neutral shade

# Make sure we set a y-limit that includes space for the annotation
if max_latency > 0:  # Only set if we have data
    arrow_y = max_latency * 1.1  # Place above the highest point in the plot
    ax.set_ylim(0, max_latency * 1.2)
else:
    arrow_y = 100  # Fallback if no data

# Add the annotation for attack start
ax.annotate('Início do ataque', 
            xy=(attack_x, max_latency * 0.7 if max_latency > 0 else 50),  # Point to the plot
            xytext=(attack_x, arrow_y),  # Text above the plot
            va='center', 
            ha='center',
            fontsize=16,
            fontweight='bold',
            color='black',
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="black", alpha=0.9),
            arrowprops=dict(
                arrowstyle="->",
                color='black',
                linewidth=3,
                connectionstyle="arc3,rad=0.0"
            ))

# Override the automatically calculated value with the correct one
post_attack_accepts = 14400


# Set axis limits
ax.set_xlim(0, 480)

# Add titles, labels
ax.set_xlabel('Tempo (s)', fontsize=22, fontweight='bold')
ax.set_ylabel('Latência Média (ms)', fontsize=22, fontweight='bold')
ax.grid(True, linewidth=1.5)

# Set x-axis ticks every 100 seconds
x_ticks = np.arange(0, 481, 100)  # from 0 to 480 with step 100
ax.set_xticks(x_ticks)
ax.tick_params(axis='both', which='major', labelsize=22, width=2, length=10, pad=10)

# Make the axes lines thicker
for spine in ax.spines.values():
    spine.set_linewidth(2.5)

# Create two separate legends
# First legend for line styles (Normal vs Anomalous)
style_elements = [
    Line2D([0], [0], color='black', linewidth=4, linestyle='-', label='Normal'),
    Line2D([0], [0], color='black', linewidth=4, linestyle=':', label='Anômalo')
]
first_legend = ax.legend(handles=style_elements, loc='upper left', 
                       fontsize=18)

# Add the first legend manually
ax.add_artist(first_legend)

# Print codes for debugging
print(f"Creating legend for codes: {sorted(encountered_codes)}")
for code in sorted(encountered_codes):
    color = colors_by_code.get(code, default_color)
    print(f"Legend element: Code {code}, Color {color}")

# Second legend for HTTP status codes
code_elements = [Line2D([0], [0], color=colors_by_code.get(code, default_color), linewidth=4, label=f'Código {code}') 
                 for code in sorted(encountered_codes)]

# Add the second legend at a different position
second_legend = ax.legend(handles=code_elements, loc='upper right', 
                         title='Códigos HTTP', fontsize=18, title_fontsize=20)

plt.tight_layout()
# Save the plot as a PNG file with white background
plt.savefig("normal_vs_anomalous_latency.png", format="png", dpi=300, 
           bbox_inches='tight', facecolor='white')

# Optional: Inform where the file is saved
print("Plot saved as 'normal_vs_anomalous_latency.png'")
