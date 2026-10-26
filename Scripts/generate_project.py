#!/usr/bin/env python3
"""Rebuild the checked-in Xcode project with no third-party tooling."""
import hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value))
def add(name, body):
    key = uid(name)
    objects[key] = body
    return key
def array(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
def ref(path):
    ext = Path(path).suffix
    types = {'.swift':'sourcecode.swift', '.xcstrings':'text.json.xcstrings', '.xcassets':'folder.assetcatalog', '.xcprivacy':'text.xml', '.plist':'text.plist.xml'}
    return add('file:'+path, f'isa = PBXFileReference; lastKnownFileType = {types.get(ext,"text")}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
app_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'SwingLab').rglob('*.swift'))
test_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'SwingLabTests').rglob('*.swift'))
ui_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'SwingLabUITests').rglob('*.swift'))
resources = ['SwingLab/Resources/Assets.xcassets', 'SwingLab/Resources/Localizable.xcstrings', 'SwingLab/Resources/InfoPlist.xcstrings', 'SwingLab/Resources/PrivacyInfo.xcprivacy']
all_paths = app_sources+test_sources+ui_sources+resources+['SwingLab/Resources/Info.plist']
refs = {path:ref(path) for path in all_paths}
products=[]
product_ids={}
for name,ext,kind in [('SwingLab','app','wrapper.application'),('SwingLabTests','xctest','wrapper.cfbundle'),('SwingLabUITests','xctest','wrapper.cfbundle')]:
    product_ids[name]=add('product:'+name,f'isa = PBXFileReference; explicitFileType = {kind}; includeInIndex = 0; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product_ids[name])
product_group=add('products',f'isa = PBXGroup; children = {array(products)}; name = Products; sourceTree = "<group>";')
groups=[]
for name,paths in [('Application',app_sources),('Resources',resources+['SwingLab/Resources/Info.plist']),('Tests',test_sources+ui_sources)]:
    groups.append(add('group:'+name,f'isa = PBXGroup; children = {array([refs[p] for p in paths])}; name = {name}; sourceTree = "<group>";'))
main_group=add('main',f'isa = PBXGroup; children = {array(groups+[product_group])}; sourceTree = "<group>";')
package=add('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
core=add('core','isa = XCSwiftPackageProductDependency; productName = SwingLabCore;')
def configs(name,base):
    ids=[]
    for config in ['Debug','Release']:
        values=dict(base)
        values['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if config=='Debug' else '-O'
        values['DEBUG_INFORMATION_FORMAT']='dwarf' if config=='Debug' else 'dwarf-with-dsym'
        if config=='Debug': values.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        body=' '.join(f'{k} = {q(v)};' for k,v in values.items())
        ids.append(add(f'config:{name}:{config}',f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};'))
    return add('configs:'+name,f'isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
def phase(name,isa,files):
    builds=[add(f'build:{name}:{p}',f'isa = PBXBuildFile; fileRef = {refs[p]};') for p in files]
    return add('phase:'+name,f'isa = {isa}; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;')
project_config=configs('project',dict(IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', CLANG_ENABLE_MODULES='YES', SWIFT_VERSION='6.0', SWIFT_STRICT_CONCURRENCY='complete', GCC_C_LANGUAGE_STANDARD='gnu17', CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER='YES', ENABLE_USER_SCRIPT_SANDBOXING='YES'))
targets=[]
for name,sources in [('SwingLab',app_sources),('SwingLabTests',test_sources),('SwingLabUITests',ui_sources)]:
    is_app=name=='SwingLab'
    settings=dict(PRODUCT_NAME='$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER='com.swinglab.app'+('' if is_app else '.'+name), CODE_SIGN_STYLE='Automatic', DEVELOPMENT_TEAM='', TARGETED_DEVICE_FAMILY='1', SUPPORTED_PLATFORMS='iphoneos iphonesimulator', SUPPORTS_MACCATALYST='NO', GENERATE_INFOPLIST_FILE='YES', MARKETING_VERSION='0.1.0', CURRENT_PROJECT_VERSION='1')
    if is_app:
        settings.update(GENERATE_INFOPLIST_FILE='NO', INFOPLIST_FILE='SwingLab/Resources/Info.plist', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', SWIFT_EMIT_LOC_STRINGS='YES', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks')
    elif name=='SwingLabTests':
        settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/SwingLab.app/SwingLab', BUNDLE_LOADER='$(TEST_HOST)')
    else: settings.update(TEST_TARGET_NAME='SwingLab')
    config=configs(name,settings)
    source_phase=phase(name+'Sources','PBXSourcesBuildPhase',sources)
    resource_phase=phase(name+'Resources','PBXResourcesBuildPhase',resources if is_app else [])
    libs=[]
    if name != "SwingLabUITests":
        libs.append(add("build:core:"+name,f'isa = PBXBuildFile; productRef = {core};'))
    fw=add('phase:'+name+'Frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {array(libs)}; runOnlyForDeploymentPostprocessing = 0;')
    deps=[]
    if not is_app:
        proxy=add('proxy:'+name,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:SwingLab")}; remoteInfo = SwingLab;')
        deps.append(add('dependency:'+name,f'isa = PBXTargetDependency; target = {uid("target:SwingLab")}; targetProxy = {proxy};'))
    product_type='application' if is_app else ('bundle.unit-test' if name=='SwingLabTests' else 'bundle.ui-testing')
    targets.append(add('target:'+name,f'isa = PBXNativeTarget; buildConfigurationList = {config}; buildPhases = {array([source_phase,fw,resource_phase])}; buildRules = (); dependencies = {array(deps)}; name = {name}; packageProductDependencies = {array([core] if name != "SwingLabUITests" else [])}; productName = {name}; productReference = {product_ids[name]}; productType = "com.apple.product-type.{product_type}";'))
langs=['en','ko','ja','zh-Hans','zh-Hant','es','pt-BR','de','fr','it','th','vi','Base']
project=add('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("target:SwingLab")} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = {array([q(x) for x in langs])}; mainGroup = {main_group}; productRefGroup = {product_group}; packageReferences = {array([package])}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
out=ROOT/'SwingLab.xcodeproj'
out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 56;\n objects = {\n'+''.join(f'  {key} = {{ {value} }};\n' for key,value in objects.items())+f' }};\n rootObject = {project};\n}}\n')
scheme=out/'xcshareddata/xcschemes'
scheme.mkdir(parents=True,exist_ok=True)
def buildref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{ "app" if name=="SwingLab" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:SwingLab.xcodeproj"/>'
(scheme/'SwingLab.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref('SwingLab')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildref('SwingLabTests')}</TestableReference><TestableReference skipped="NO">{buildref('SwingLabUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('SwingLab')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('SwingLab')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated project: {len(app_sources)} app sources, {len(test_sources)} integration sources, {len(ui_sources)} UI test sources.')
