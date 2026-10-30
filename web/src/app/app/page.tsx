import type { Metadata } from "next";
import { GymApp } from "@/components/GymApp";

export const metadata: Metadata = { title: "GPS-GYM" };

export default function AppPage() {
  return <GymApp />;
}
