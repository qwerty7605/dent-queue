<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (!Schema::hasTable('users')) {
            return;
        }

        $hasFirstName = Schema::hasColumn('users', 'first_name');
        $hasMiddleName = Schema::hasColumn('users', 'middle_name');
        $hasLastName = Schema::hasColumn('users', 'last_name');
        $hasUsername = Schema::hasColumn('users', 'username');
        $hasLocation = Schema::hasColumn('users', 'location');
        $hasGender = Schema::hasColumn('users', 'gender');
        $hasIsActive = Schema::hasColumn('users', 'is_active');

        if (!$hasFirstName || !$hasMiddleName || !$hasLastName || !$hasUsername || !$hasLocation || !$hasGender || !$hasIsActive) {
            Schema::table('users', function (Blueprint $table) use (
                $hasFirstName,
                $hasMiddleName,
                $hasLastName,
                $hasUsername,
                $hasLocation,
                $hasGender,
                $hasIsActive
            ) {
                if (!$hasFirstName) {
                    $table->string('first_name')->nullable();
                }

                if (!$hasMiddleName) {
                    $table->string('middle_name')->nullable();
                }

                if (!$hasLastName) {
                    $table->string('last_name')->nullable();
                }

                if (!$hasUsername) {
                    $table->string('username')->nullable()->unique();
                }

                if (!$hasLocation) {
                    $table->string('location')->nullable();
                }

                if (!$hasGender) {
                    $table->string('gender')->nullable();
                }

                if (!$hasIsActive) {
                    $table->boolean('is_active')->default(true);
                }
            });
        }

        $hasName = Schema::hasColumn('users', 'name');
        $hasEmail = Schema::hasColumn('users', 'email');

        if (!Schema::hasColumn('users', 'first_name')) {
            return;
        }

        $selectColumns = ['id', 'first_name', 'last_name', 'username', 'is_active'];
        if ($hasName) {
            $selectColumns[] = 'name';
        }
        if ($hasEmail) {
            $selectColumns[] = 'email';
        }

        $users = DB::table('users')->select($selectColumns)->orderBy('id')->get();

        foreach ($users as $user) {

            $legacyName = $hasName ? trim((string) ($user->name ?? '')) : '';
            $nameParts = preg_split('/\s+/', $legacyName, -1, PREG_SPLIT_NO_EMPTY) ?: [];

            $updates = [];

            if (empty($user->first_name)) {
                if (count($nameParts) > 0) {
                    $updates['first_name'] = $nameParts[0];
                } else {
                    $updates['first_name'] = 'User';
                }
            }

            if (empty($user->last_name)) {
                if (count($nameParts) > 1) {
                    $updates['last_name'] = implode(' ', array_slice($nameParts, 1));
                } else {
                    $updates['last_name'] = 'Account';
                }
            }

            if (empty($user->username)) {
                $email = $hasEmail ? (string) ($user->email ?? '') : '';
                $updates['username'] = $this->generateUniqueUsername((int) $user->id, $email, (string) ($updates['first_name'] ?? $user->first_name));
            }

            if (property_exists($user, 'is_active') && $user->is_active === null) {
                $updates['is_active'] = true;
            }

            if (!empty($updates)) {
                DB::table('users')->where('id', $user->id)->update($updates);
            }
        }
    }

    /**
     * Reverse the migrations.
     *
     * This migration is intentionally non-destructive to protect existing user data.
     */
    public function down(): void
    {
        // Intentionally left blank.
    }

    private function generateUniqueUsername(int $userId, string $email, string $fallback): string
    {
        $base = trim(Str::lower(Str::before($email, '@')));

        if ($base === '') {
            $base = trim(Str::lower($fallback));
        }

        if ($base === '') {
            $base = 'user';
        }

        $base = preg_replace('/[^a-z0-9_]+/', '_', $base) ?: 'user';
        $base = trim($base, '_');

        if ($base === '') {
            $base = 'user';
        }

        $base = Str::limit($base, 45, '');

        $candidate = $base;
        $suffix = 1;

        while (
            DB::table('users')
                ->where('id', '<>', $userId)
                ->where('username', $candidate)
                ->exists()
        ) {
            $suffixText = (string) $suffix;
            $trimmedBase = Str::limit($base, 45 - strlen($suffixText), '');
            $candidate = $trimmedBase . $suffixText;
            $suffix++;
        }

        return $candidate;
    }
};
