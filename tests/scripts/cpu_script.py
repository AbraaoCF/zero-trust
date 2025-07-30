import pandas as pd
import matplotlib.pyplot as plt
import io
import seaborn as sns

# Data retrieved from OpenSearch Dashboard for the duration of experiments
csv_data = """filters,"container_name.keyword","CPU Cores (%)"
Proxy,service,"14.539512278103247"
Proxy,"envoy-service","3.8931707092901555"
Motor de Logs,opensearch,"8.74750001579523"
Motor de Logs,"envoy-service","5.2914999455213545"
Motor de Logs,service,"3.2275610133642103"
Motor de Logs,"state-storage","2.416097549403586"
Motor de Políticas,"opa-service-1","23.168333162864048"
Motor de Políticas,"envoy-service","4.362250000238419"
Motor de Políticas,"usage-tracker","3.0204166871650764"
Motor de Políticas,"opal-server","1.490833342075348"
Motor de Políticas,service,"0.6259999975562096"
"""

# Read the data into a DataFrame
data = pd.read_csv(io.StringIO(csv_data))

filter_order = ["Proxy", "Motor de Logs", "Motor de Políticas"]

# Pivot data for stacked bar chart
data_pivot = data.pivot(index="filters", columns="container_name.keyword", values="CPU Cores (%)")

# Reorder index based on filter order
data_pivot = data_pivot.reindex(filter_order)

# Use a better color palette
custom_palette = sns.color_palette("Paired")

# Plot
fig, ax = plt.subplots(figsize=(10, 6))
data_pivot.plot(kind="bar", stacked=True, color=custom_palette, ax=ax)

# Labels and title
ax.set_ylabel("Cores de CPU (%)", fontsize=14, fontweight='bold')
ax.set_xlabel("")
# ax.set_title("Stacked Column Chart of CPU Usage by Container")
ax.legend(title="Componente", bbox_to_anchor=(1, 1), loc='upper left', fontsize=12, title_fontsize=14, frameon=False)
ax.set_xticklabels(data_pivot.index, rotation=0, ha="center", fontsize=14)
ax.grid(True, which='both', linestyle='--', linewidth=0.5, axis='y', zorder=0)

# Ensure bars are in front of grid
ax.set_axisbelow(True)

# Show plot
plt.tight_layout()
plt.savefig("experiment_cpu_plot.png", format="png", dpi=300)
