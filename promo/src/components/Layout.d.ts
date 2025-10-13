interface LayoutProps {
    children: React.ReactNode;
    currentPage: string;
    onNavigate: (page: string) => void;
}
export declare function Layout({ children, currentPage, onNavigate }: LayoutProps): import("react/jsx-runtime").JSX.Element;
export {};
