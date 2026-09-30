import { defineConfig, passthroughImageService } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
  site: 'https://001123.github.io',
  base: '/lab-hetzner-gitops-k3s',
  image: {
    service: passthroughImageService(),
  },
  integrations: [
    starlight({
      title: 'Hetzner k3s GitOps',
      defaultLocale: 'root',
      locales: {
        root: {
          label: 'English',
          lang: 'en',
        },
        vi: {
          label: 'Tiếng Việt',
          lang: 'vi',
        },
      },
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/001123/lab-hetzner-gitops-k3s',
        },
      ],
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Overview & Goals', slug: 'getting-started/overview' },
            { label: 'Prerequisites & Toolchain', slug: 'getting-started/prerequisites' },
          ],
        },
        {
          label: 'Architecture & Design',
          items: [
            { label: 'System Architecture', slug: 'architecture/overview' },
            { label: 'Secrets Management (SOPS + AGE)', slug: 'architecture/security-sops' },
          ],
        },
        {
          label: 'Runbook & Operations',
          items: [
            { label: 'Bootstrap k3s & ArgoCD', slug: 'runbook/bootstrap' },
            { label: 'GitOps Workloads & Sync Waves', slug: 'runbook/gitops-apps' },
          ],
        },
        {
          label: 'Troubleshooting & Gotchas',
          items: [
            { label: 'Common Issues & Notes', slug: 'troubleshooting/common-issues' },
          ],
        },
      ],
    }),
  ],
});
