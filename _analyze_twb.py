import xml.etree.ElementTree as ET
import re

twb_path = r'C:\Users\ytaketani\Rays-CRM-Agent\_tableau_temp\2026 CRM Dashboards.twb'
tree = ET.parse(twb_path)
root = tree.getroot()

# 1. Find all datasources and their connections
print("=" * 80)
print("DATA SOURCES AND CONNECTIONS")
print("=" * 80)
for ds in root.iter('datasource'):
    name = ds.get('name', 'unnamed')
    caption = ds.get('caption', '')
    if name == 'Parameters':
        continue
    print(f"\n--- Datasource: {caption or name} ---")
    
    # Find connection details
    for conn in ds.iter('named-connection'):
        conn_name = conn.get('name', '')
        conn_caption = conn.get('caption', '')
        print(f"  Connection: {conn_caption or conn_name}")
        for c in conn.iter('connection'):
            server = c.get('server', '')
            dbname = c.get('dbname', '')
            schema = c.get('schema', '')
            warehouse = c.get('warehouse', '')
            if server:
                print(f"    Server: {server}")
            if dbname:
                print(f"    Database: {dbname}")
            if schema:
                print(f"    Schema: {schema}")
            if warehouse:
                print(f"    Warehouse: {warehouse}")
    
    # Find relation/table references
    for rel in ds.iter('relation'):
        rel_type = rel.get('type', '')
        rel_name = rel.get('name', '')
        rel_table = rel.get('table', '')
        if rel_table:
            print(f"  Table: {rel_table} (alias: {rel_name})")

# 2. Find ALL calculated fields
print("\n" + "=" * 80)
print("ALL CALCULATED FIELDS")
print("=" * 80)
for ds in root.iter('datasource'):
    ds_name = ds.get('caption', ds.get('name', 'unnamed'))
    if ds_name == 'Parameters':
        continue
    
    calcs_found = False
    for col in ds.iter('column'):
        calc = col.find('calculation')
        if calc is not None:
            formula = calc.get('formula', '')
            if formula:
                if not calcs_found:
                    print(f"\n--- {ds_name} ---")
                    calcs_found = True
                col_name = col.get('caption', col.get('name', ''))
                print(f"\n  [{col_name}]")
                print(f"    Formula: {formula}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
