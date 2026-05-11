<?php

namespace Tests\Unit;

use App\Models\Appointment;
use App\Models\AuditTrail;
use App\Models\ClinicSetting;
use App\Models\DoctorUnavailability;
use App\Models\PatientNotification;
use App\Models\PatientRecord;
use App\Models\Queue;
use App\Models\Report;
use App\Models\Role;
use App\Models\Service;
use App\Models\StaffNotification;
use App\Models\StaffRecord;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ModelContractTest extends TestCase
{
    use RefreshDatabase;

    /** @param class-string<Model> $modelClass */
    #[DataProvider('modelProvider')]
    public function test_model_table_exists(string $modelClass): void
    {
        $model = new $modelClass();

        $this->assertTrue(
            Schema::hasTable($model->getTable()),
            sprintf('%s table [%s] does not exist.', $modelClass, $model->getTable()),
        );
    }

    /** @param class-string<Model> $modelClass */
    #[DataProvider('modelProvider')]
    public function test_model_declares_a_primary_key(string $modelClass): void
    {
        $model = new $modelClass();

        $this->assertNotSame('', $model->getKeyName());
        $this->assertContains($model->getKeyType(), ['int', 'string']);
    }

    /** @param class-string<Model> $modelClass */
    #[DataProvider('modelProvider')]
    public function test_model_has_explicit_mass_assignment_contract(string $modelClass): void
    {
        $model = new $modelClass();

        $this->assertTrue(
            $model->getFillable() !== [] || $model->getGuarded() !== [],
            sprintf('%s should declare fillable or guarded attributes.', $modelClass),
        );
    }

    /** @param class-string<Model> $modelClass */
    #[DataProvider('modelProvider')]
    public function test_model_can_be_serialized_to_array(string $modelClass): void
    {
        $model = new $modelClass();

        $this->assertIsArray($model->toArray());
    }

    /**
     * @return array<string, array{class-string<Model>}>
     */
    public static function modelProvider(): array
    {
        return [
            'appointment' => [Appointment::class],
            'audit trail' => [AuditTrail::class],
            'clinic setting' => [ClinicSetting::class],
            'doctor unavailability' => [DoctorUnavailability::class],
            'patient notification' => [PatientNotification::class],
            'patient record' => [PatientRecord::class],
            'queue' => [Queue::class],
            'report' => [Report::class],
            'role' => [Role::class],
            'service' => [Service::class],
            'staff notification' => [StaffNotification::class],
            'staff record' => [StaffRecord::class],
            'user' => [User::class],
        ];
    }
}
