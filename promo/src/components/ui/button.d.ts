import * as React from "react";
import { type VariantProps } from "class-variance-authority";
declare const buttonVariants: (props?: {
    variant?: "default" | "destructive" | "outline" | "secondary" | "ghost" | "link";
    size?: "default" | "sm" | "lg" | "icon";
} & import("class-variance-authority/types").ClassProp) => string;
declare const Button: React.ForwardRefExoticComponent<Omit<React.ClassAttributes<HTMLButtonElement> & React.ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<(props?: {
    variant?: "default" | "destructive" | "outline" | "secondary" | "ghost" | "link";
    size?: "default" | "sm" | "lg" | "icon";
} & import("class-variance-authority/types").ClassProp) => string> & {
    asChild?: boolean;
}, "ref"> & React.RefAttributes<HTMLButtonElement>>;
export { Button, buttonVariants };
