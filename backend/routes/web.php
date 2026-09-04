<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\SimulatePaymentController;

Route::get('/', function () {
    return view('welcome');
});
Route::get('/dev/simulate-payment', [SimulatePaymentController::class, 'show']);
Route::post('/dev/simulate-payment/confirm', [SimulatePaymentController::class, 'confirm']);
