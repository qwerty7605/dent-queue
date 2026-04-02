<?php

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => \App\Http\Middleware\CheckRole::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $expectsApiJson = static function (Request $request): bool {
            return $request->expectsJson() || $request->is('api/*');
        };

        $normalizeErrors = static function (array $errors): array {
            return collect($errors)
                ->map(static function (mixed $messages): array {
                    return collect((array) $messages)
                        ->map(static fn (mixed $message): string => (string) $message)
                        ->values()
                        ->all();
                })
                ->all();
        };

        $exceptions->render(function (ValidationException $exception, Request $request) use ($expectsApiJson, $normalizeErrors) {
            if (!$expectsApiJson($request)) {
                return null;
            }

            return response()->json([
                'type' => 'validation_error',
                'message' => 'The given data was invalid.',
                'errors' => $normalizeErrors($exception->errors()),
            ], $exception->status);
        });

        $exceptions->render(function (AuthenticationException $exception, Request $request) use ($expectsApiJson) {
            if (!$expectsApiJson($request)) {
                return null;
            }

            return response()->json([
                'type' => 'authentication_error',
                'message' => $exception->getMessage() !== ''
                    ? $exception->getMessage()
                    : 'Unauthenticated.',
            ], 401);
        });

        $exceptions->render(function (AuthorizationException $exception, Request $request) use ($expectsApiJson) {
            if (!$expectsApiJson($request)) {
                return null;
            }

            return response()->json([
                'type' => 'authorization_error',
                'message' => $exception->getMessage() !== ''
                    ? $exception->getMessage()
                    : 'This action is unauthorized.',
            ], 403);
        });

        $exceptions->render(function (HttpExceptionInterface $exception, Request $request) use ($expectsApiJson) {
            if (!$expectsApiJson($request)) {
                return null;
            }

            $statusCode = $exception->getStatusCode();
            $fallbackMessage = Response::$statusTexts[$statusCode] ?? 'Request failed.';

            return response()->json([
                'type' => 'request_error',
                'message' => $exception->getMessage() !== ''
                    ? $exception->getMessage()
                    : $fallbackMessage,
            ], $statusCode);
        });

        $exceptions->render(function (\Throwable $exception, Request $request) use ($expectsApiJson) {
            if (!$expectsApiJson($request)) {
                return null;
            }

            report($exception);

            return response()->json([
                'type' => 'server_error',
                'message' => config('app.debug')
                    ? $exception->getMessage()
                    : 'Server error. Please try again later.',
            ], 500);
        });
    })->create();
