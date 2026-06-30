import unittest

from flow_clone.text import clean_transcript


class NumberedListCleanupTests(unittest.TestCase):
    def test_explicit_number_markers_create_numbered_list(self) -> None:
        self.assertEqual(
            clean_transcript("I have three things number one bread number two milk number three butter"),
            "I have three things:\n"
            "1. Bread\n"
            "2. Milk\n"
            "3. Butter",
        )

    def test_ordinal_markers_create_numbered_list(self) -> None:
        self.assertEqual(clean_transcript("first bread second milk third butter"), "1. Bread\n2. Milk\n3. Butter")

    def test_point_item_and_step_markers_create_numbered_list(self) -> None:
        self.assertEqual(clean_transcript("point one bread point two milk point three butter"), "1. Bread\n2. Milk\n3. Butter")
        self.assertEqual(clean_transcript("item one bread item two milk item three butter"), "1. Bread\n2. Milk\n3. Butter")
        self.assertEqual(clean_transcript("step one open app step two click continue"), "1. Open app\n2. Click continue")

    def test_numbered_list_intro_variations(self) -> None:
        self.assertEqual(
            clean_transcript("I have three items first bread second sugar third eggs"),
            "I have three items:\n"
            "1. Bread\n"
            "2. Sugar\n"
            "3. Eggs",
        )
        self.assertEqual(
            clean_transcript("these are the following three things first bread second sugar third eggs"),
            "These are the following three things:\n"
            "1. Bread\n"
            "2. Sugar\n"
            "3. Eggs",
        )
        self.assertEqual(
            clean_transcript("I need numbered list point one bread point two sugar point three eggs"),
            "I need numbered list:\n"
            "1. Bread\n"
            "2. Sugar\n"
            "3. Eggs",
        )

    def test_following_ways_with_one_two_three_markers_creates_numbered_list(self) -> None:
        self.assertEqual(
            clean_transcript(
                "It helps developers in the following ways one, they understand how to use it, "
                "two that it is open source, three it is local."
            ),
            "It helps developers in the following ways:\n"
            "1. They understand how to use it\n"
            "2. It is open source\n"
            "3. It is local",
        )
        self.assertEqual(
            clean_transcript(
                "I think this helps developers in the following ways one they understand the power of the model "
                "two that it is open source three it runs locally"
            ),
            "I think this helps developers in the following ways:\n"
            "1. They understand the power of the model\n"
            "2. It is open source\n"
            "3. It runs locally",
        )
        self.assertEqual(
            clean_transcript(
                "It helps developers in three ways one they understand how to use it two that it is open source three it is local"
            ),
            "It helps developers in three ways:\n"
            "1. They understand how to use it\n"
            "2. It is open source\n"
            "3. It is local",
        )

    def test_marker_items_drop_leading_is(self) -> None:
        self.assertEqual(
            clean_transcript("number one is bread number two is milk number three is butter"),
            "1. Bread\n"
            "2. Milk\n"
            "3. Butter",
        )

    def test_marker_words_are_removed_when_they_leak_into_items(self) -> None:
        self.assertEqual(
            clean_transcript("By the way these are three things:\n1. Number 1 bread\n2. Number 2 sugar\n3. Number 3 eggs"),
            "By the way these are three things:\n"
            "1. Bread\n"
            "2. Sugar\n"
            "3. Eggs",
        )

    def test_counted_plain_list_with_and_creates_numbered_list(self) -> None:
        self.assertEqual(
            clean_transcript("we need to work on the following three things bread milk and butter"),
            "We need to work on the following three things:\n"
            "1. Bread\n"
            "2. Milk\n"
            "3. Butter",
        )

    def test_comma_list_without_numbered_cue_stays_bulleted(self) -> None:
        self.assertEqual(
            clean_transcript("I want to bring the following items bread, milk, and butter"),
            "I want to bring the following items:\n"
            "- Bread\n"
            "- Milk\n"
            "- Butter",
        )

    def test_bulleted_cue_creates_bullets_for_simple_plain_items(self) -> None:
        self.assertEqual(
            clean_transcript("you can also add bulleted things bread butter milk"),
            "You can also add bulleted things:\n"
            "- Bread\n"
            "- Butter\n"
            "- Milk",
        )
        self.assertEqual(
            clean_transcript("you can also add bulleted things bread, butter, milk"),
            "You can also add bulleted things:\n"
            "- Bread\n"
            "- Butter\n"
            "- Milk",
        )

    def test_comma_list_can_have_more_items_than_spoken_count(self) -> None:
        self.assertEqual(
            clean_transcript(
                "let us say you wanted to run the following three things a campaign for Nemotron models, "
                "a campaign for Kumo models, a campaign for certification, a campaign for events"
            ),
            "Let us say you wanted to run the following three things:\n"
            "1. A campaign for Nemotron models\n"
            "2. A campaign for Kumo models\n"
            "3. A campaign for certification\n"
            "4. A campaign for events",
        )

    def test_inline_benefits_with_number_markers_creates_numbered_list(self) -> None:
        self.assertEqual(
            clean_transcript(
                "This means we have three benefits. Number one None of your data is going to a third party server, "
                "so it is private and secure. Number two it is open source. Number three it is essentially free "
                "instead of fifteen, twenty dollars a month."
            ),
            "This means we have three benefits:\n"
            "1. None of your data is going to a third party server, so it is private and secure\n"
            "2. It is open source\n"
            "3. It is essentially free instead of fifteen, twenty dollars a month",
        )
        self.assertEqual(
            clean_transcript("This gives us three benefits. First it is private. Second it is open source. Third it is free."),
            "This gives us three benefits:\n"
            "1. It is private\n"
            "2. It is open source\n"
            "3. It is free",
        )

    def test_ordinal_adjectives_inside_items_are_not_list_markers(self) -> None:
        self.assertEqual(
            clean_transcript(
                "This means we have three benefits. Number one this does not go to a third party server. "
                "Number two it is open source. Number three it is free."
            ),
            "This means we have three benefits:\n"
            "1. This does not go to a third party server\n"
            "2. It is open source\n"
            "3. It is free",
        )

    def test_ordinary_comma_sentence_is_not_forced_into_list(self) -> None:
        self.assertEqual(clean_transcript("I want to bring bread, milk, and butter"), "I want to bring bread, milk, and butter")

    def test_duration_language_is_not_forced_into_numbered_list(self) -> None:
        self.assertEqual(
            clean_transcript("When I press these keys you know it takes about two to s second a half for the app to show up"),
            "When I press these keys you know it takes about two to s second a half for the app to show up",
        )
        self.assertEqual(
            clean_transcript("When I press these keys you know it takes about two s second a half for the app to show up"),
            "When I press these keys you know it takes about two s second a half for the app to show up",
        )


if __name__ == "__main__":
    unittest.main()
