import zipfile
from pathlib import Path

skill_path = Path('C:/Users/86198/.qclaw/skills/task-context-relay')
output_path = Path('C:/Users/86198/.qclaw/skills')
skill_filename = output_path / 'task-context-relay.skill'

with zipfile.ZipFile(skill_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for file_path in skill_path.rglob('*'):
        if file_path.is_file():
            arcname = file_path.relative_to(skill_path.parent)
            zipf.write(file_path, arcname)
            print(f'Added: {arcname}')

print(f'Successfully packaged to: {skill_filename}')
