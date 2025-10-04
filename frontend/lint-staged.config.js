export default {
  'src/**/*.{ts,tsx,js,jsx}': [
    'pnpm exec eslint --fix',
    'pnpm exec prettier --write'
  ],
  'src/**/*.{css,scss,md}': 'pnpm exec prettier --write'
};
