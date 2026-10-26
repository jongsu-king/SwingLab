#!/usr/bin/env python3
import copy, unittest
from check_localizations import scan, validate, LOCALES

def catalog(keys):
    return {'strings':{key:{'localizations':{locale:{'stringUnit':{'state':'translated','value':key}} for locale in LOCALES}} for key in keys}}

class LocalizationChecks(unittest.TestCase):
    def test_core_enum_and_nested_helper_are_reachable(self):
        keys,errors=scan({'Core.swift':'enum P { var localizationKey: LocalizationKey { switch self { case .measured: "Measured" } } }',
            'UI.swift':'func row(_ key: LocalizationKey) { prefs.text(key) }; row("Short"); prefs.text(value.localizationKey)'})
        self.assertEqual(keys,{'Measured','Short'});self.assertEqual(errors,[])
        data=catalog(keys);del data['strings']['Measured']['localizations']['ko']
        self.assertIn('Measured: missing ko',validate(keys,data))
    def test_unknown_dynamic_is_rejected_even_with_fallback(self):
        for expression in ['runtimeKey','runtimeKey ?? "Fallback"','"Hello \\(name)"']:
            self.assertTrue(scan({'UI.swift':'prefs.text('+expression+')'})[1])
    def test_typed_ternary_initializer(self):
        keys,errors=scan({'UI.swift':'let key: LocalizationKey = flag ? "One" : "Many"\nprefs.text(key)'})
        self.assertEqual(keys,{'One','Many'});self.assertEqual(errors,[])
    def test_enum_mutation_new_single_word_fails(self):
        keys,_=scan({'Core.swift':'var localizationKey: LocalizationKey { "NewKey" }'})
        self.assertEqual(len(validate(keys,catalog([]))),12)
    def test_plural_locale_and_required_form(self):
        data=catalog({'count.swings'})
        data['strings']['count.swings']['localizations']['en']={'variations':{'plural':{'other':{'stringUnit':{'state':'translated','value':'%1$lld swings'}}}}}
        self.assertTrue(any('missing plural forms' in e for e in validate({'count.swings'},data)))
    def test_typed_array_options_are_roots(self):
        keys,_=scan({'UI.swift':'let options = ["Fairway", "Rough"] as [LocalizationKey]'})
        self.assertEqual(keys,{'Fairway','Rough'})
    def test_memberwise_initializer(self):
        keys,errors=scan({'UI.swift':'struct Notice { let key: LocalizationKey }; let notice = Notice(key: "NewNotice"); prefs.text(notice.key)'})
        self.assertIn('NewNotice',keys);self.assertEqual(errors,[])
    def test_typed_collections_and_defaults_are_roots(self):
        for source in ['let values: [LocalizationKey] = ["Missing"]',
                       'func labels() -> [LocalizationKey] { ["Missing"] }',
                       'func label(_ key: LocalizationKey = "Missing") { prefs.text(key) }; label()']:
            keys,errors=scan({'UI.swift':source})
            self.assertIn('Missing',keys);self.assertEqual(errors,[])
    def test_localization_alias_is_rejected(self):
        self.assertTrue(scan({'UI.swift':'let translate = prefs.text; translate("Missing")'})[1])
    def test_swiftui_literal_is_a_root(self):
        self.assertIn('DirectKey',scan({'UI.swift':'Text("DirectKey")'})[0])
    def test_plural_structure_cannot_be_removed_in_one_locale(self):
        data=catalog({'count.swings'})
        data['strings']['count.swings']['localizations']['en']={'variations':{'plural':{
            'one':{'stringUnit':{'state':'translated','value':'%1$lld swing'}},
            'other':{'stringUnit':{'state':'translated','value':'%1$lld swings'}}}}}
        self.assertTrue(any('missing plural structure' in e for e in validate({'count.swings'},data)))
    def test_memberwise_collection(self):
        keys,errors=scan({'UI.swift':'struct Notice { let keys: [LocalizationKey] }; let notice = Notice(keys: ["Missing"]); prefs.text(notice.keys.first!)'})
        self.assertIn('Missing',keys);self.assertEqual(errors,[])
    def test_generic_literal_factory_is_rejected(self):
        self.assertTrue(scan({'UI.swift':'func labels<T: ExpressibleByStringLiteral>() -> [T] { ["Missing"] }'})[1])
    def test_many_plural_form_is_required(self):
        data=catalog({'count.swings'})
        data['strings']['count.swings']['localizations']['fr']={'variations':{'plural':{
            'one':{'stringUnit':{'state':'translated','value':'%1$lld swing'}},
            'other':{'stringUnit':{'state':'translated','value':'%1$lld swings'}}}}}
        self.assertTrue(any('many' in e for e in validate({'count.swings'},data)))
    def test_no_manual_constructor_bypass(self):
        self.assertTrue(scan({'UI.swift':'prefs.text(LocalizationKey(stringLiteral: value))'})[1])

if __name__=='__main__':unittest.main()
