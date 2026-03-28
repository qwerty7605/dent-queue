# AGD-87 — Appointment Trends Backend (Daily / Weekly / Monthly)

## Objective

Provide the backend data source for the appointment trends chart on the Reports page.

## What It Is

An admin reports API capability that returns appointment volume trends grouped by:

- Daily
- Weekly
- Monthly

## Where It Is Located

Admin Dashboard -> Reports

## What The Admin Sees

The existing appointment trends chart UI populated with live trend data instead of placeholder buckets.

## Why It Matters

It allows admins to identify demand patterns, monitor busy periods, and make scheduling decisions using real appointment history.

## Description

Implement the backend support for the appointment trends UI introduced in AGD-86. The endpoint should return grouped appointment counts for the selected trend view and remain safe when no records exist.

The current frontend is already prepared for API integration and supports empty states. This ticket should focus only on the backend contract, grouping logic, and tests.

## Scope Of Work

- Add an admin reports trend endpoint or extend the existing reports API for trend data
- Support a granularity parameter for `daily`, `weekly`, and `monthly`
- Group appointment totals by the requested time bucket
- Return a frontend-friendly response with labels and counts
- Keep empty datasets valid and non-breaking
- Restrict access to authorized admin users only
- Add automated backend tests for the new trend responses

## Suggested Response Shape

```json
{
  "data": {
    "view": "daily",
    "points": [
      { "label": "Mon", "count": 12 },
      { "label": "Tue", "count": 8 }
    ]
  }
}
```

## Acceptance Criteria

- Backend returns appointment trend data for daily view
- Backend returns appointment trend data for weekly view
- Backend returns appointment trend data for monthly view
- Response shape is stable and ready for the existing chart UI
- Empty data returns a valid success response with no layout-breaking payload assumptions
- Access is limited to admins
- Automated tests cover the supported views and empty-data behavior
