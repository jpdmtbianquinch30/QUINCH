<?php

namespace Tests\Unit;

use App\Support\CsvSafe;
use PHPUnit\Framework\TestCase;

class CsvSafeTest extends TestCase
{
    public function test_formula_prefixes_are_neutralised(): void
    {
        foreach (['=1+1', '+33', '-2+3', '@SUM(A1)', "\tcmd", "\rcmd"] as $dangerous) {
            $this->assertSame("'" . $dangerous, CsvSafe::cell($dangerous), 'Cellule non neutralisée : ' . json_encode($dangerous));
        }
    }

    public function test_harmless_values_are_left_untouched(): void
    {
        $this->assertSame('Fatou Diop', CsvSafe::cell('Fatou Diop'));
        $this->assertSame('', CsvSafe::cell(''));
        $this->assertSame(1500.5, CsvSafe::cell(1500.5));
        $this->assertSame(-3, CsvSafe::cell(-3));
        $this->assertNull(CsvSafe::cell(null));
        $this->assertSame('a=b', CsvSafe::cell('a=b'));
    }

    public function test_row_applies_to_every_cell(): void
    {
        $this->assertSame(["'=HYPERLINK(\"x\")", 'ok', 12], CsvSafe::row(['=HYPERLINK("x")', 'ok', 12]));
    }
}
