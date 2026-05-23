"""
Entrena ResNet-50 (timm) — alineado al notebook 03-resnet50.

  python -m src.train_resnet50 --train-dir data/plantas_train --valid-dir data/plantas_valid
"""

from __future__ import annotations

import argparse
import time
from collections import defaultdict
from pathlib import Path

import timm
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms

from src.transforms import IMAGENET_MEAN, IMAGENET_STD, IMG_SIZE


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--train-dir", required=True)
    p.add_argument("--valid-dir", required=True)
    p.add_argument("--epochs", type=int, default=5)
    p.add_argument("--batch-size", type=int, default=64)
    p.add_argument("--lr", type=float, default=1e-3)
    p.add_argument("--num-workers", type=int, default=4)
    p.add_argument("--checkpoint-dir", default="checkpoints")
    p.add_argument("--max-per-class", type=int, default=None)
    return p.parse_args()


def _subset_limited(ds: datasets.ImageFolder, max_per_class: int | None) -> Subset | datasets.ImageFolder:
    if not max_per_class:
        return ds
    counts: dict[str, int] = defaultdict(int)
    indices = []
    for i, (_, label) in enumerate(ds.samples):
        cls = ds.classes[label]
        if counts[cls] < max_per_class:
            counts[cls] += 1
            indices.append(i)
    return Subset(ds, indices)


def train_epoch(model, loader, criterion, optimizer, device):
    model.train()
    total_loss = 0.0
    correct = 0
    total = 0
    for images, labels in loader:
        images, labels = images.to(device), labels.to(device)
        optimizer.zero_grad()
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()
        total_loss += loss.item() * images.size(0)
        correct += (logits.argmax(1) == labels).sum().item()
        total += images.size(0)
    return total_loss / total, correct / total


@torch.no_grad()
def eval_epoch(model, loader, criterion, device):
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0
    for images, labels in loader:
        images, labels = images.to(device), labels.to(device)
        logits = model(images)
        loss = criterion(logits, labels)
        total_loss += loss.item() * images.size(0)
        correct += (logits.argmax(1) == labels).sum().item()
        total += images.size(0)
    return total_loss / total, correct / total


def main() -> None:
    args = parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")

    train_tf = transforms.Compose(
        [
            transforms.Resize((IMG_SIZE, IMG_SIZE)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(15),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )
    eval_tf = transforms.Compose(
        [
            transforms.Resize((IMG_SIZE, IMG_SIZE)),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )

    train_base = datasets.ImageFolder(args.train_dir, transform=train_tf)
    val_base = datasets.ImageFolder(args.valid_dir, transform=eval_tf)
    train_ds = _subset_limited(train_base, args.max_per_class)
    val_ds = _subset_limited(val_base, args.max_per_class)
    num_classes = len(train_base.classes)

    train_loader = DataLoader(
        train_ds,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        pin_memory=device.type == "cuda",
    )
    val_loader = DataLoader(
        val_ds,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
        pin_memory=device.type == "cuda",
    )

    model = timm.create_model("resnet50", pretrained=True, num_classes=num_classes)
    model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    ckpt_dir = Path(args.checkpoint_dir)
    ckpt_dir.mkdir(parents=True, exist_ok=True)
    best_acc = 0.0
    best_path = ckpt_dir / "resnet50.pt"

    for epoch in range(1, args.epochs + 1):
        t0 = time.time()
        tr_loss, tr_acc = train_epoch(model, train_loader, criterion, optimizer, device)
        va_loss, va_acc = eval_epoch(model, val_loader, criterion, device)
        scheduler.step()
        print(
            f"Epoch {epoch}/{args.epochs} | "
            f"train loss={tr_loss:.4f} acc={tr_acc:.4f} | "
            f"val loss={va_loss:.4f} acc={va_acc:.4f} | "
            f"{time.time()-t0:.0f}s"
        )
        if va_acc > best_acc:
            best_acc = va_acc
            torch.save(model.state_dict(), best_path)
            print(f"  ✓ Mejor modelo ({best_acc:.4f}) → {best_path}")

    print(f"\nListo. Mejor val_acc={best_acc:.4f}")


if __name__ == "__main__":
    main()
