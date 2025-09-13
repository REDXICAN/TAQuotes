@echo off
echo ============================================================
echo DELETING E SERIES PRODUCTS FROM FIREBASE
echo ============================================================
echo.
echo This will delete 27 E series products from Firebase.
echo.
pause

firebase database:remove "/products/product_0014" -y
firebase database:remove "/products/product_0015" -y
firebase database:remove "/products/product_0016" -y
firebase database:remove "/products/product_0017" -y
firebase database:remove "/products/product_0018" -y
firebase database:remove "/products/product_0019" -y
firebase database:remove "/products/product_0020" -y
firebase database:remove "/products/product_0021" -y
firebase database:remove "/products/product_0022" -y
firebase database:remove "/products/product_0023" -y
firebase database:remove "/products/product_0024" -y
firebase database:remove "/products/product_0025" -y
firebase database:remove "/products/product_0026" -y
firebase database:remove "/products/product_0027" -y
firebase database:remove "/products/product_0028" -y
firebase database:remove "/products/product_0029" -y
firebase database:remove "/products/product_0030" -y
firebase database:remove "/products/product_0031" -y
firebase database:remove "/products/product_0032" -y
firebase database:remove "/products/product_0033" -y
firebase database:remove "/products/product_0034" -y
firebase database:remove "/products/product_0035" -y
firebase database:remove "/products/product_0036" -y
firebase database:remove "/products/product_0037" -y
firebase database:remove "/products/product_0038" -y
firebase database:remove "/products/product_0039" -y
firebase database:remove "/products/product_0040" -y

echo.
echo ============================================================
echo DELETION COMPLETE
echo ============================================================
echo All 27 E series products have been removed from Firebase!
pause