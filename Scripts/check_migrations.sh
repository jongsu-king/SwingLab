#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
migration_check_dir=$(mktemp -d /tmp/swinglab-migrations.XXXXXX)
trap 'rm -rf "$migration_check_dir"' EXIT
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

# Execute every migration test method against macOS SwiftData using the same model sources.
# This supplements, and never replaces, the simulator's hosted XCTest suite.
python3 - "$migration_check_dir" <<'PY'
from pathlib import Path
import re, sys
target = Path(sys.argv[1])
runner = ['import Foundation', '@main struct MigrationRunner {', '    @MainActor static func main() throws {']
count = 0
for class_name in ['SchemaMigrationTests', 'PracticeSessionTests']:
    source = Path(f'SwingLabTests/{class_name}.swift').read_text()
    source = source.replace('import XCTest\n', 'import Foundation\n').replace('@testable import SwingLab\n', '')
    (target / f'{class_name}.swift').write_text(source)
    tests = re.findall(r'func (test\w+)\(\) throws', source)
    assert tests, f'No test methods found in {class_name}'
    count += len(tests)
    for name in tests:
        runner += [f'        try {class_name}().{name}()', f'        print("PASS {name}")']
runner += [f'        print("PASS {count} migration/session tests on macOS SwiftData (not iOS simulator XCTest)")', '    }', '}']
(target / 'Runner.swift').write_text('\n'.join(runner) + '\n')
PY

swiftc -swift-version 6 -enable-testing -emit-library -emit-module -module-name SwingLabCore \
    Sources/SwingLabCore/*.swift -emit-module-path "$migration_check_dir/SwingLabCore.swiftmodule" \
    -o "$migration_check_dir/libSwingLabCore.dylib"
swiftc -swift-version 6 -module-name SwingLab -parse-as-library \
    -I "$migration_check_dir" -L "$migration_check_dir" -lSwingLabCore \
    -Xlinker -rpath -Xlinker "$migration_check_dir" \
    SwingLab/Core/Models/*.swift SwingLab/Core/Persistence/Schema*.swift \
    SwingLab/Core/Persistence/PracticeSessionStore.swift SwingLab/Core/Persistence/PersistenceRollback.swift SwingLab/Core/Persistence/AnalysisPersistence.swift \
    Scripts/MigrationTestHarness.swift "$migration_check_dir/SchemaMigrationTests.swift" \
    "$migration_check_dir/PracticeSessionTests.swift" \
    "$migration_check_dir/Runner.swift" -o "$migration_check_dir/MigrationChecks"
"$migration_check_dir/MigrationChecks"
