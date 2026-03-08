<?php

namespace Database\Seeders;

use App\Models\Service;
use Illuminate\Database\Seeder;

class ServiceSeeder extends Seeder
{
    public function run(): void
    {
        $services = [
            [
                'name' => 'Dental Check-up',
                'description' => 'Routine oral examination and consultation.',
            ],
            [
                'name' => 'Dental Panoramic X-ray',
                'description' => 'Panoramic imaging for full-mouth assessment.',
            ],
            [
                'name' => 'Root Canal',
                'description' => 'Endodontic treatment to save an infected tooth.',
            ],
            [
                'name' => 'Teeth Cleaning',
                'description' => 'Professional prophylaxis and tartar removal.',
            ],
            [
                'name' => 'Teeth Whitening',
                'description' => 'Cosmetic whitening treatment for stained teeth.',
            ],
            [
                'name' => 'Tooth Extraction',
                'description' => 'Simple or surgical tooth removal procedure.',
            ],
        ];

        foreach ($services as $service) {
            Service::updateOrCreate(
                ['name' => $service['name']],
                [
                    'description' => $service['description'],
                    'is_active' => true,
                ],
            );
        }
    }
}
