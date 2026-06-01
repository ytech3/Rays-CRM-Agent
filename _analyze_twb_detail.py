import xml.etree.ElementTree as ET

twb_path = r'C:\Users\ytaketani\Rays-CRM-Agent\_tableau_temp\2026 CRM Dashboards.twb'
tree = ET.parse(twb_path)
root = tree.getroot()

# Find the actual SQL relations / table references for each primary datasource
print("=" * 80)
print("DETAILED DATA SOURCE DEFINITIONS (relations, custom SQL, joins)")
print("=" * 80)

seen = set()
for ds in root.iter('datasource'):
    name = ds.get('name', 'unnamed')
    caption = ds.get('caption', '')
    display = caption or name
    if display == 'Parameters' or display in seen:
        continue
    
    # Only process primary datasource definitions (ones with connections)
    has_conn = False
    for _ in ds.iter('named-connection'):
        has_conn = True
        break
    if not has_conn:
        continue
    
    seen.add(display)
    print(f"\n{'='*60}")
    print(f"DATASOURCE: {display}")
    print(f"{'='*60}")
    
    # Find all relation elements (tables, custom SQL, joins)
    for rel in ds.iter('relation'):
        rel_type = rel.get('type', '')
        rel_name = rel.get('name', '')
        rel_table = rel.get('table', '')
        rel_connection = rel.get('connection', '')
        
        if rel_type == 'table' and rel_table and rel_table != '[Extract].[Extract]':
            print(f"\n  TABLE: {rel_table}")
            if rel_name:
                print(f"  ALIAS: {rel_name}")
        elif rel_type == 'text':
            # Custom SQL
            text = rel.text
            if text and text.strip():
                print(f"\n  CUSTOM SQL ({rel_name}):")
                print(f"  {'-'*50}")
                for line in text.strip().split('\n'):
                    print(f"    {line}")
                print(f"  {'-'*50}")
        elif rel_type == 'join':
            join_type = rel.get('join', '')
            print(f"\n  JOIN: {join_type}")
            # Get join clause
            for clause in rel.iter('clause'):
                clause_type = clause.get('type', '')
                print(f"    Clause type: {clause_type}")
                for expr in clause.iter('expression'):
                    op = expr.get('op', '')
                    print(f"    Op: {op}")

# Also get column mappings for activity-related datasources
print("\n\n" + "=" * 80)
print("COLUMN DETAILS FOR ACTIVITY-RELATED DATASOURCES")
print("=" * 80)

seen2 = set()
for ds in root.iter('datasource'):
    caption = ds.get('caption', ds.get('name', ''))
    if caption in ('Parameters',) or caption in seen2:
        continue
    
    has_conn = False
    for _ in ds.iter('named-connection'):
        has_conn = True
        break
    if not has_conn:
        continue
    
    if 'Activit' in caption or 'Opps' in caption:
        seen2.add(caption)
        print(f"\n--- {caption} ---")
        print("  Columns (from metadata-records):")
        for mr in ds.iter('metadata-record'):
            cls = mr.get('class', '')
            if cls == 'column':
                local_name = ''
                remote_name = ''
                remote_type = ''
                for child in mr:
                    if child.tag == 'local-name':
                        local_name = child.text or ''
                    elif child.tag == 'remote-name':
                        remote_name = child.text or ''
                    elif child.tag == 'remote-type':
                        remote_type = child.text or ''
                if remote_name:
                    print(f"    {remote_name} ({remote_type}) -> {local_name}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
