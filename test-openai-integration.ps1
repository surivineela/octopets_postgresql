#!/usr/bin/env pwsh

# OpenAI Integration Test Script for Octopets
# Run this script after starting the application to test the new endpoints

Write-Host "🐾 Testing Octopets OpenAI Integration" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

$baseUrl = "https://localhost:7243"

# Test 1: Health Check
Write-Host "`n1. Testing Health Check..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$baseUrl/api/pet-analysis/health" -Method GET -SkipCertificateCheck
    Write-Host "✅ Health Check Passed" -ForegroundColor Green
    Write-Host "Status: $($healthResponse.status)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Health Check Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Pet Analysis
Write-Host "`n2. Testing Pet Analysis..." -ForegroundColor Yellow
$petData = @{
    petName = "Buddy"
    petType = "Dog"
    breed = "Golden Retriever"
    age = 3
    size = "Large"
    temperamentDescription = "Friendly, energetic, loves people and other dogs"
    specialNeeds = @()
    activityLevel = "High"
} | ConvertTo-Json

try {
    $analysisResponse = Invoke-RestMethod -Uri "$baseUrl/api/pet-analysis/analyze" -Method POST -Body $petData -ContentType "application/json" -SkipCertificateCheck
    Write-Host "✅ Pet Analysis Completed" -ForegroundColor Green
    Write-Host "Pet: $($analysisResponse.petName)" -ForegroundColor Cyan
    Write-Host "Score: $($analysisResponse.suitabilityScore)" -ForegroundColor Cyan
    Write-Host "Recommended Venues: $($analysisResponse.recommendedVenueTypes -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Pet Analysis Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Venue Recommendations
Write-Host "`n3. Testing Venue Recommendations..." -ForegroundColor Yellow
$preferences = @("outdoor dining", "social environment") | ConvertTo-Json

try {
    $queryParams = "petType=Dog&breed=Labrador"
    $recommendationsResponse = Invoke-RestMethod -Uri "$baseUrl/api/pet-analysis/recommendations?$queryParams" -Method POST -Body $preferences -ContentType "application/json" -SkipCertificateCheck
    Write-Host "✅ Venue Recommendations Retrieved" -ForegroundColor Green
    Write-Host "Recommendations: $($recommendationsResponse.recommendations -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Venue Recommendations Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Venue Description Generation
Write-Host "`n4. Testing Venue Description Generation..." -ForegroundColor Yellow
$allowedPets = @("dogs", "cats") | ConvertTo-Json

try {
    $queryParams = "venueName=The Pet Café&venueType=cafe"
    $descriptionResponse = Invoke-RestMethod -Uri "$baseUrl/api/pet-analysis/venue-description?$queryParams" -Method POST -Body $allowedPets -ContentType "application/json" -SkipCertificateCheck
    Write-Host "✅ Venue Description Generated" -ForegroundColor Green
    Write-Host "Description: $($descriptionResponse.description)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Venue Description Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎉 Testing Complete!" -ForegroundColor Green
Write-Host "Note: If any tests failed, ensure:" -ForegroundColor Yellow
Write-Host "1. The application is running (dotnet run --project apphost)" -ForegroundColor Yellow
Write-Host "2. OpenAI API key is configured in appsettings.Development.json" -ForegroundColor Yellow
Write-Host "3. You have sufficient OpenAI credits" -ForegroundColor Yellow