"""A smoke render exercising both a held frame and padded narration."""

from manim import (
    DOWN,
    LEFT,
    RIGHT,
    UP,
    Arrow,
    Circle,
    FadeIn,
    Scene,
    Text,
    Transform,
    VGroup,
)


def label(text: str, size: int = 32) -> Text:
    return Text(text, font="DejaVu Sans", font_size=size)


class SharedHistory(Scene):
    def construct(self) -> None:
        title = label("Git-worktrees", 48).to_edge(UP)
        history = label("Gedeelde commits").shift(UP)
        main = label("Werkmap: main").shift(LEFT * 3 + DOWN)
        feature = label("Werkmap: feature").shift(RIGHT * 3 + DOWN)
        arrows = VGroup(
            Arrow(history.get_bottom(), main.get_top()),
            Arrow(history.get_bottom(), feature.get_top()),
        )
        self.add(title)
        self.play(FadeIn(history), run_time=0.5)
        self.play(FadeIn(arrows), FadeIn(main), FadeIn(feature), run_time=1)
        self.wait(0.5)


class SeparateFiles(Scene):
    def construct(self) -> None:
        title = label("Afzonderlijke bestanden", 44).to_edge(UP)
        main = label("main: versie 1").shift(LEFT * 3)
        feature = label("feature: versie 1").shift(RIGHT * 3)
        self.add(title, main, feature)
        self.wait(1)
        changed = label("feature: gewijzigd").move_to(feature)
        self.play(Transform(feature, changed), run_time=2)
        marker = Circle(radius=0.18, color="#55cc88").next_to(feature, DOWN)
        self.play(FadeIn(marker), run_time=0.5)
        self.wait(6.5)
