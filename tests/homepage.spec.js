const { test, expect } = require('@playwright/test');

test.describe('Cedar and Sage Apothecary - Homepage', () => {
  test('has correct page title', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Cedar and Sage/i);
  });

  test('displays hero section', async ({ page }) => {
    await page.goto('/');
    const hero = page.locator('[data-testid="hero"], .hero, header');
    await expect(hero.first()).toBeVisible();
  });

  test('navigation links are present', async ({ page }) => {
    await page.goto('/');
    const nav = page.locator('nav');
    await expect(nav).toBeVisible();
  });
});

test.describe('Cedar and Sage Apothecary - Shop', () => {
  test('products are displayed', async ({ page }) => {
    await page.goto('/shop');
    const products = page.locator('[data-testid="product-card"], .product-card, .product');
    await expect(products.first()).toBeVisible();
  });

  test('add to cart works', async ({ page }) => {
    await page.goto('/shop');
    const addToCartBtn = page.locator('[data-testid="add-to-cart"], .add-to-cart').first();
    await addToCartBtn.click();
    const cartCount = page.locator('[data-testid="cart-count"], .cart-count');
    await expect(cartCount).toContainText('1');
  });
});

test.describe('Cedar and Sage Apothecary - Mobile', () => {
  test('mobile menu opens correctly', async ({ page }) => {
    await page.goto('/');
    const menuToggle = page.locator('[data-testid="mobile-menu-toggle"], .hamburger, .mobile-menu-btn');
    if (await menuToggle.isVisible()) {
      await menuToggle.click();
      const mobileMenu = page.locator('[data-testid="mobile-menu"], .mobile-menu');
      await expect(mobileMenu).toBeVisible();
    }
  });
});
