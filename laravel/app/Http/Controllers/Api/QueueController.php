<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Queue;

use App\Services\QueueService;

class QueueController extends Controller
{
    protected $queueService;

    public function __construct(QueueService $queueService)
    {
        $this->queueService = $queueService;
    }

    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        //
    }

    /**
     * Store a newly created resource in storage (Generate next queue number).
     */
    public function store(Request $request)
    {
        //
    }

    /**
     * Call the next patient (Update next is_called to true).
     */
    public function callNext()
    {
        //
    }
}
