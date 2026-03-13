<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PatientRecord;
use Illuminate\Http\Request;

class PatientRecordController extends Controller
{
    /**
     * Search patient records by name or contact number.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function search(Request $request)
    {
        $query = $request->query('query');

        if (blank($query)) {
            return response()->json([
                'data' => []
            ]);
        }

        $searchTerm = '%' . $query . '%';
        $terms = array_filter(explode(' ', trim($query)));

        $patients = PatientRecord::query()
            ->where(function ($q) use ($terms, $searchTerm) {
                // If there are multiple words (like "Kyle Aldea"), we want to make sure
                // all words appear in either first, last or middle name.
                foreach ($terms as $term) {
                    $termLike = '%' . $term . '%';
                    $q->where(function ($subQ) use ($termLike) {
                        $subQ->where('first_name', 'LIKE', $termLike)
                             ->orWhere('last_name', 'LIKE', $termLike)
                             ->orWhere('middle_name', 'LIKE', $termLike);
                    });
                }
                
                // Allow contact number matching for the full string
                $q->orWhere('contact_number', 'LIKE', $searchTerm);
            })
            ->limit(20)
            ->get();

        // Map to return only the requested fields
        $mappedPatients = $patients->map(function ($patient) {
            $middleInitial = $patient->middle_name ? ' ' . substr($patient->middle_name, 0, 1) . '.' : '';
            $fullName = trim("{$patient->first_name}{$middleInitial} {$patient->last_name}");
            
            return [
                'patient_id' => $patient->patient_id,
                'full_name' => $fullName,
                'contact_number' => $patient->contact_number,
            ];
        });

        return response()->json([
            'data' => $mappedPatients
        ]);
    }
}
