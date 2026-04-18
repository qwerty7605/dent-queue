<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        $app = parent::createApplication();

        $defaultConnection = $app['config']->get('database.default');
        $sqliteDatabase = $app['config']->get('database.connections.sqlite.database');

        if ($defaultConnection === 'sqlite' && $this->shouldUseInMemorySqlite($sqliteDatabase)) {
            $app['config']->set('database.connections.sqlite.database', ':memory:');
        }

        return $app;
    }

    private function shouldUseInMemorySqlite(mixed $database): bool
    {
        if (! is_string($database) || $database === '' || $database === ':memory:') {
            return false;
        }

        if (str_starts_with($database, '/') || preg_match('/^[A-Za-z]:[\\\\\\/]/', $database) === 1) {
            return false;
        }

        return ! str_contains($database, DIRECTORY_SEPARATOR);
    }
}
