import xml.etree.ElementTree as ET

twb_path = r'C:\Users\ytaketani\Rays-CRM-Agent\_tableau_temp\2026 CRM Dashboards.twb'
tree = ET.parse(twb_path)
root = tree.getroot()

# Find custom SQL for DM Salesforce Activities Prod and Opps and Activities Prod
target_sources = ['DM Salesforce Activities Prod', 'Opps and Activities Prod']
seen = set()

for ds in root.iter('datasource'):
    caption = ds.get('caption', ds.get('name', ''))
    if caption not in target_sources:
        continue
    
    # Only process primary datasource definitions (ones with connections)
    has_conn = False
    for _ in ds.iter('named-connection'):
        has_conn = True
        break
    if not has_conn:
        continue
    
    if caption in seen:
        continue
    seen.add(caption)
    
    print(f"\n{'='*80}")
    print(f"DATASOURCE: {caption}")
    print(f"{'='*80}")
    
    # Find all relation elements
    for rel in ds.iter('relation'):
        rel_type = rel.get('type', '')
        rel_name = rel.get('name', '')
        rel_table = rel.get('table', '')
        
        if rel_type == 'text':
            text = rel.text
            if text and text.strip():
                print(f"\n  CUSTOM SQL ({rel_name}):")
                print(f"  {'-'*70}")
                for line in text.strip().split('\n'):
                    print(f"    {line}")
                print(f"  {'-'*70}")
        elif rel_type == 'table' and rel_table and rel_table != '[Extract].[Extract]':
            print(f"\n  TABLE: {rel_table} (alias: {rel_name})")
    
    # Find all columns with metadata
    print(f"\n  COLUMNS:")
    for mr in ds.iter('metadata-record'):
        cls = mr.get('class', '')
        if cls == 'column':
            local_name = ''
            remote_name = ''
            remote_type = ''
            parent_name = ''
            for child in mr:
                if child.tag == 'local-name':
                    local_name = child.text or ''
                elif child.tag == 'remote-name':
                    remote_name = child.text or ''
                elif child.tag == 'remote-type':
                    remote_type = child.text or ''
                elif child.tag == 'parent-name':
                    parent_name = child.text or ''
            if remote_name:
                print(f"    {remote_name} -> {local_name} (type: {remote_type}, parent: {parent_name})")

print("\n\nDONE")
