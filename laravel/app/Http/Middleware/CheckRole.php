<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $role
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next, ...$roles): Response
    {
        if (!$request->user() || !in_array(strtolower($request->user()->role->name), array_map('strtolower', $roles))) {
            return response()->json([
                'message' => 'Unauthorized. Restricted to ' . implode(' or ', $roles) . ' only.'
            ], 403);
        }

        return $next($request);
    }
}
