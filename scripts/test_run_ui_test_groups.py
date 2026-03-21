"""Tests for run_ui_test_groups."""

from __future__ import annotations

import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from run_ui_test_groups import (
    derive_group_result_bundle_path,
    group_selection_args_by_fixture,
    infer_app_path,
    load_fixture_manifest,
    selection_arg_to_identifier,
)


class SelectionArgTests(unittest.TestCase):
    def test_selection_arg_to_identifier_extracts_xctest_identifier(self) -> None:
        self.assertEqual(
            selection_arg_to_identifier(
                "-only-testing:AndBibleUITests/AndBibleUITests/testBookmarkSelectionNavigatesReaderToSeededReference"
            ),
            "AndBibleUITests/AndBibleUITests/testBookmarkSelectionNavigatesReaderToSeededReference",
        )

    def test_selection_arg_to_identifier_rejects_non_only_testing_argument(self) -> None:
        with self.assertRaises(ValueError):
            selection_arg_to_identifier("-skip-testing:AndBibleUITests/AndBibleUITests/testOne")


class FixtureManifestTests(unittest.TestCase):
    def test_load_fixture_manifest_requires_non_empty_string_values(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            manifest_path = pathlib.Path(temp_dir) / "manifest.json"
            manifest_path.write_text(json.dumps({"AndBibleUITests/AndBibleUITests/testOne": ""}))
            with self.assertRaises(ValueError):
                load_fixture_manifest(manifest_path)

    def test_group_selection_args_by_fixture_preserves_selection_order_within_scenarios(self) -> None:
        selection_args = [
            "-only-testing:AndBibleUITests/AndBibleUITests/testBookmarkSelectionNavigatesReaderToSeededReference",
            "-only-testing:AndBibleUITests/AndBibleUITests/testHistorySelectionNavigatesReaderToSeededReference",
            "-only-testing:AndBibleUITests/AndBibleUITests/testBookmarkRowDeletePreservesOtherRowsAcrossReopen",
        ]
        manifest = {
            "AndBibleUITests/AndBibleUITests/testBookmarkSelectionNavigatesReaderToSeededReference": "bookmark-navigation",
            "AndBibleUITests/AndBibleUITests/testHistorySelectionNavigatesReaderToSeededReference": "history-single",
            "AndBibleUITests/AndBibleUITests/testBookmarkRowDeletePreservesOtherRowsAcrossReopen": "bookmark-multirow",
        }
        self.assertEqual(
            group_selection_args_by_fixture(selection_args, manifest),
            [
                (
                    "bookmark-navigation",
                    [
                        "-only-testing:AndBibleUITests/AndBibleUITests/testBookmarkSelectionNavigatesReaderToSeededReference"
                    ],
                ),
                (
                    "history-single",
                    [
                        "-only-testing:AndBibleUITests/AndBibleUITests/testHistorySelectionNavigatesReaderToSeededReference"
                    ],
                ),
                (
                    "bookmark-multirow",
                    [
                        "-only-testing:AndBibleUITests/AndBibleUITests/testBookmarkRowDeletePreservesOtherRowsAcrossReopen"
                    ],
                ),
            ],
        )

    def test_group_selection_args_by_fixture_requires_manifest_entry_for_every_selected_test(self) -> None:
        with self.assertRaises(ValueError):
            group_selection_args_by_fixture(
                ["-only-testing:AndBibleUITests/AndBibleUITests/testOne"],
                {},
            )


class PathDerivationTests(unittest.TestCase):
    def test_derive_group_result_bundle_path_suffixes_multi_group_paths(self) -> None:
        derived = derive_group_result_bundle_path(
            pathlib.Path(".artifacts/AndBibleTests-ui.xcresult"),
            scenario="bookmark-filter",
            group_index=2,
            total_groups=3,
        )
        self.assertEqual(
            derived,
            pathlib.Path(".artifacts/AndBibleTests-ui-group-02-bookmark-filter.xcresult"),
        )

    def test_infer_app_path_uses_configuration_and_scheme(self) -> None:
        self.assertEqual(
            infer_app_path(
                derived_data_path=pathlib.Path(".derivedData"),
                configuration="Debug",
                scheme="AndBible",
            ),
            pathlib.Path(".derivedData/Build/Products/Debug-iphonesimulator/AndBible.app"),
        )


if __name__ == "__main__":
    unittest.main()
