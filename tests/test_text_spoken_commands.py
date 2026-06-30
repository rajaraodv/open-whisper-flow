import unittest

from flow_clone.text import clean_transcript


class SpokenCommandCleanupTests(unittest.TestCase):
    def test_repeated_next_line_at_start_creates_blank_line(self) -> None:
        self.assertEqual(clean_transcript("next line please new line please thanks Raja"), "\n\nThanks Raja")

    def test_punctuation_after_repeated_next_line_is_removed(self) -> None:
        self.assertEqual(clean_transcript("next line please new line please comma period thanks Raja"), "\n\nThanks Raja")

    def test_next_paragraph_punctuation_artifacts_are_removed(self) -> None:
        self.assertEqual(clean_transcript("next paragraph please comma comma thanks Raja"), "\n\nThanks Raja")

    def test_repeated_next_line_inside_text_creates_blank_line(self) -> None:
        self.assertEqual(
            clean_transcript("what do you think of this demo next line please new line please thanks Raja"),
            "What do you think of this demo\n\nThanks Raja",
        )

    def test_blank_line_after_numbered_list_does_not_join_final_item(self) -> None:
        self.assertEqual(
            clean_transcript(
                "I wanted to do the following three things number one attract developers "
                "number two showcase open source models and number three spread the word "
                "next line please new line please thanks next line please Raja"
            ),
            "I wanted to do the following three things:\n"
            "1. Attract developers\n"
            "2. Showcase open source models\n"
            "3. Spread the word\n\n"
            "Thanks\n"
            "Raja",
        )

    def test_email_greeting_formats_when_body_has_list_and_signoff(self) -> None:
        self.assertEqual(
            clean_transcript(
                "hi Alison I wanted to do the following three things number one attract developers "
                "number two showcase open source models and number three spread the word "
                "next line please new line please thanks next line please Raja",
                email_mode=True,
            ),
            "Hi Alison,\n\n"
            "I wanted to do the following three things:\n"
            "1. Attract developers\n"
            "2. Showcase open source models\n"
            "3. Spread the word\n\n"
            "Thanks\n"
            "Raja",
        )

    def test_quotes_and_brackets_are_formatted(self) -> None:
        self.assertEqual(clean_transcript("open quote hello world close quote"), '"hello world"')
        self.assertEqual(clean_transcript("open bracket important close bracket"), "(important)")

    def test_quote_unquote_keeps_command_words_literal(self) -> None:
        self.assertEqual(clean_transcript("quote next line unquote"), '"next line"')
        self.assertEqual(clean_transcript("quote next space line unquote"), '"next line"')

    def test_quote_variants_keep_command_words_literal(self) -> None:
        self.assertEqual(clean_transcript("open quote next line close quote"), '"next line"')
        self.assertEqual(clean_transcript("start quote new paragraph end quote"), '"new paragraph"')
        self.assertEqual(clean_transcript("begin quote comma end quote"), '"comma"')
        self.assertEqual(clean_transcript("coat next line uncoat"), '"next line"')
        self.assertEqual(clean_transcript("coat next space line uncoat"), '"next line"')

    def test_next_line_requires_please(self) -> None:
        self.assertEqual(clean_transcript("for next line say quote next line unquote please"), 'For next line say "next line" please')
        self.assertEqual(clean_transcript("next line"), "Next line")
        self.assertEqual(clean_transcript("next line please thanks Raja"), "\nThanks Raja")

    def test_bare_quote_words_emit_double_quotes(self) -> None:
        self.assertEqual(clean_transcript("quote"), '"')
        self.assertEqual(clean_transcript("unquote"), '"')
        self.assertEqual(clean_transcript("quote comma unquote"), '"comma"')
        self.assertEqual(clean_transcript("code unquote"), '""')

    def test_common_phrases_are_not_removed_as_fillers(self) -> None:
        self.assertEqual(
            clean_transcript("as you know we need to build compelling demos"),
            "As you know we need to build compelling demos",
        )
        self.assertEqual(clean_transcript("as you know as you know as you know"), "As you know as you know as you know")
        self.assertEqual(
            clean_transcript("as we need to build compelling demos as as as"),
            "As we need to build compelling demos as",
        )

    def test_only_obvious_hesitation_sounds_are_removed(self) -> None:
        self.assertEqual(clean_transcript("um we need to build compelling demos"), "We need to build compelling demos")
        self.assertEqual(clean_transcript("uh we need to build compelling demos"), "We need to build compelling demos")
        self.assertEqual(clean_transcript("ah we need to build compelling demos"), "We need to build compelling demos")


if __name__ == "__main__":
    unittest.main()
