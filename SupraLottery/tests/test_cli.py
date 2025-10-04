import io
import unittest
from contextlib import redirect_stdout

from supra.scripts import cli


class CliTestCase(unittest.TestCase):
    def test_list_outputs_commands(self) -> None:
        buf = io.StringIO()
        with redirect_stdout(buf):
            cli.main(["--list"])
        output = buf.getvalue()
        self.assertIn("calc-min-balance", output)
        self.assertIn("manual-draw", output)

    def test_calc_min_balance_subcommand(self) -> None:
        buf = io.StringIO()
        with redirect_stdout(buf):
            cli.main(
                [
                    "calc-min-balance",
                    "--max-gas-price",
                    "1",
                    "--max-gas-limit",
                    "2",
                    "--verification-gas",
                    "3",
                    "--json",
                ]
            )
        data = buf.getvalue()
        self.assertIn('"min_balance": "150"', data)
        self.assertIn('"recommended_deposit"', data)

    def test_unknown_command(self) -> None:
        with self.assertRaises(SystemExit) as exc:
            cli.main(["unknown"])
        self.assertEqual(exc.exception.code, 2)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
