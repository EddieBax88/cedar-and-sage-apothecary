const { test, expect } = require('@playwright/test');

test.describe('Cedar and Sage Apothecary - Checkout Flow', () => {
  test('cart page loads', async ({ page }) => {
    await page.goto('/cart');
    await expect(page).not.toHaveURL(/error/);
  });

  test('checkout form validation', async ({ page }) => {
    await page.goto('/checkout');
    // Attempt to submit empty form
    const submitBtn = page.locator('[data-testid="submit-order"], button[type="submit"]').first();
    if (await submitBtn.isVisible()) {
      await submitBtn.click();
      // Expect validation errors to appear
      const errorMsg = page.locator('[data-testid="error"], .error, .field-error');
      await expect(errorMsg.first()).toBeVisible();
    }
  });

  test('promo code field accepts input', async ({ page }) => {
    await page.goto('/cart');
    const promoInput = page.locator('[data-testid="promo-code"], input[name="promo"]');
    if (await promoInput.isVisible()) {
      await promoInput.fill('WELCOME10');
      await expect(promoInput).toHaveValue('WELCOME10');
    }
  });
});
