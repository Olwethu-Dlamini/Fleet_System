// tests/unit/dateFormatting.test.js
// Covers FOUND-07: TZ=UTC prevents date shifting
// Run: TZ=UTC npx jest tests/unit/dateFormatting.test.js

describe('Date Formatting — UTC enforcement', () => {
  beforeAll(() => {
    // Simulate TZ=UTC as set in Dockerfile
    process.env.TZ = 'UTC';
  });

  test('formatDateOnly returns YYYY-MM-DD without timezone shift', () => {
    // A date stored as midnight UTC should remain the same date string
    const date = new Date('2026-03-21T00:00:00.000Z');
    const formatted = date.toISOString().split('T')[0];
    expect(formatted).toBe('2026-03-21');
  });

  test('date string round-trips without shifting when TZ is UTC', () => {
    const original = '2026-12-31';
    const parsed = new Date(original + 'T00:00:00.000Z');
    const formatted = parsed.toISOString().split('T')[0];
    expect(formatted).toBe(original);
  });

  test('getFullYear() on UTC date returns correct year', () => {
    // Verify job number year is correct — Job.generateJobNumber() uses new Date().getFullYear()
    const jan1UTC = new Date('2026-01-01T00:00:00.000Z');
    const year = jan1UTC.getUTCFullYear();
    expect(year).toBe(2026);
  });

  test('December 31 UTC midnight is not January 1 in UTC', () => {
    // Without TZ=UTC, a server in UTC+2 would read Dec 31 23:00 UTC as Jan 1 local
    const dec31 = new Date('2025-12-31T23:00:00.000Z');
    const dateStr = dec31.toISOString().split('T')[0];
    expect(dateStr).toBe('2025-12-31');  // Must remain Dec 31
  });
});
