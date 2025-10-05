import type { ReactElement, ReactNode } from 'react';
import clsx from 'clsx';
import './GlassCard.css';

interface GlassCardProps {
  title?: string;
  subtitle?: string;
  accent?: 'primary' | 'secondary' | 'neutral';
  footer?: ReactNode;
  children: ReactNode;
  className?: string;
}

const accentClass: Record<NonNullable<GlassCardProps['accent']>, string> = {
  primary: 'glass-card--accent-primary',
  secondary: 'glass-card--accent-secondary',
  neutral: 'glass-card--accent-neutral',
};

export function GlassCard({
  title,
  subtitle,
  accent = 'neutral',
  footer,
  children,
  className,
}: GlassCardProps): ReactElement {
  return (
    <article className={clsx('glass-card', accentClass[accent], className)}>
      {(title || subtitle) && (
        <header className="glass-card__header">
          {title && <h2>{title}</h2>}
          {subtitle && <p>{subtitle}</p>}
        </header>
      )}
      <div className="glass-card__body">{children}</div>
      {footer && <footer className="glass-card__footer">{footer}</footer>}
    </article>
  );
}
